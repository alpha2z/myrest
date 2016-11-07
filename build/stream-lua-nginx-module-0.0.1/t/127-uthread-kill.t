# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua::Stream;use t::StapThread;

our $GCScript = $t::StapThread::GCScript;
our $StapScript = $t::StapThread::StapScript;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5 + 2);

$ENV{TEST_NGINX_RESOLVER} ||= '8.8.8.8';
$ENV{TEST_NGINX_MEMCACHED_PORT} ||= '11211';

#no_shuffle();
no_long_string();
run_tests();

__DATA__

=== TEST 1: kill pending sleep
--- stream_server_config
    content_by_lua_block {
        function f()
            ngx.say("hello from f()")
            ngx.sleep(1)
        end

        local t, err = ngx.thread.spawn(f)
        if not t then
            ngx.say("failed to spawn thread: ", err)
            return
        end

        ngx.say("thread created: ", coroutine.status(t))

        collectgarbage()

        local ok, err = ngx.thread.kill(t)
        if not ok then
            ngx.say("failed to kill thread: ", err)
            return
        end

        ngx.say("killed")

        local ok, err = ngx.thread.kill(t)
        if not ok then
            ngx.say("failed to kill thread: ", err)
            return
        end
    }
--- stap2 eval: $::StapScript
--- stap eval: $::GCScript
--- stap_out
create 2 in 1
spawn user thread 2 in 1
delete thread 2
terminate 1: ok
delete thread 1

--- stream_response
hello from f()
thread created: running
killed
failed to kill thread: already waited or killed

--- no_error_log
[error]
--- error_log
lua clean up the timer for pending ngx.sleep



=== TEST 2: already waited
--- stream_server_config
    content_by_lua_block {
        function f()
            ngx.say("hello from f()")
            ngx.sleep(0.001)
            return 32
        end

        local t, err = ngx.thread.spawn(f)
        if not t then
            ngx.say("failed to spawn thread: ", err)
            return
        end

        ngx.say("thread created: ", coroutine.status(t))

        collectgarbage()

        local ok, res = ngx.thread.wait(t)
        if not ok then
            ngx.say("failed to kill thread: ", res)
            return
        end

        ngx.say("waited: ", res)

        local ok, err = ngx.thread.kill(t)
        if not ok then
            ngx.say("failed to kill thread: ", err)
            return
        end
    }
--- stap2 eval: $::StapScript
--- stap eval: $::GCScript
--- stap_out
create 2 in 1
spawn user thread 2 in 1
terminate 2: ok
delete thread 2
terminate 1: ok
delete thread 1

--- stream_response
hello from f()
thread created: running
waited: 32
failed to kill thread: already waited or killed

--- no_error_log
[error]
lua clean up the timer for pending ngx.sleep



=== TEST 3: kill pending resolver
--- stream_server_config
    lua_resolver agentzh.org:12345;
    content_by_lua_block {
        function f()
            local sock = ngx.socket.tcp()
            sock:connect("some.agentzh.org", 12345)
        end

        local t, err = ngx.thread.spawn(f)
        if not t then
            ngx.say("failed to spawn thread: ", err)
            return
        end

        ngx.say("thread created: ", coroutine.status(t))

        collectgarbage()

        local ok, err = ngx.thread.kill(t)
        if not ok then
            ngx.say("failed to kill thread: ", err)
            return
        end

        ngx.say("killed")
    }
--- stap2 eval: $::StapScript
--- stap eval: $::GCScript
--- stap_out
create 2 in 1
spawn user thread 2 in 1
delete thread 2
terminate 1: ok
delete thread 1

--- stream_response
thread created: running
killed

--- no_error_log
[error]
--- error_log
lua tcp socket abort resolver
resolve name done: -2



=== TEST 4: kill pending connect
--- stream_server_config
    lua_resolver $TEST_NGINX_RESOLVER;
    content_by_lua_block {
        local ready = false
        function f()
            local sock = ngx.socket.tcp()
            sock:connect("agentzh.org", 80)
            sock:close()
            ready = true
            sock:settimeout(10000)
            sock:connect("agentzh.org", 12345)
        end

        local t, err = ngx.thread.spawn(f)
        if not t then
            ngx.say("failed to spawn thread: ", err)
            return
        end

        ngx.say("thread created: ", coroutine.status(t))

        collectgarbage()

        while not ready do
            ngx.sleep(0.001)
        end

        local ok, err = ngx.thread.kill(t)
        if not ok then
            ngx.say("failed to kill thread: ", err)
            return
        end

        ngx.say("killed")
    }
--- stap2 eval: $::StapScript
--- stap eval: $::GCScript
--- stap_out
create 2 in 1
spawn user thread 2 in 1
delete thread 2
terminate 1: ok
delete thread 1

--- stream_response
thread created: running
killed

--- no_error_log
[error]
lua tcp socket abort resolver
--- grep_error_log: stream lua finalize socket
--- grep_error_log_out
stream lua finalize socket
stream lua finalize socket

--- error_log



=== TEST 5: kill a thread already terminated
--- stream_server_config
    content_by_lua_block {
        function f()
            return
        end

        local t, err = ngx.thread.spawn(f)
        if not t then
            ngx.say("failed to spawn thread: ", err)
            return
        end

        ngx.say("thread created: ", coroutine.status(t))

        collectgarbage()

        local ok, err = ngx.thread.kill(t)
        if not ok then
            ngx.say("failed to kill thread: ", err)
            return
        end

        ngx.say("killed")
    }
--- stap2 eval: $::StapScript
--- stream_response
thread created: zombie
failed to kill thread: already terminated

--- no_error_log
[error]
[alert]
lua tcp socket abort resolver
--- error_log



=== TEST 6: kill self
--- stream_server_config
    content_by_lua_block {
        local ok, err = ngx.thread.kill(coroutine.running())
        if not ok then
            ngx.say("failed to kill main thread: ", err)
        else
            ngx.say("killed main thread.")
        end

        function f()
            local ok, err = ngx.thread.kill(coroutine.running())
            if not ok then
                ngx.say("failed to kill user thread: ", err)
            else
                ngx.say("user thread thread.")
            end

        end

        local t, err = ngx.thread.spawn(f)
        if not t then
            ngx.say("failed to spawn thread: ", err)
            return
        end

        ngx.say("thread created: ", coroutine.status(t))
    }
--- stap2 eval: $::StapScript
--- stream_response
failed to kill main thread: not user thread
failed to kill user thread: killer not parent
thread created: zombie

--- no_error_log
[error]
[alert]
stream lua tcp socket abort resolver
--- error_log

