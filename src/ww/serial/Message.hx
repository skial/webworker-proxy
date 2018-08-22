package ww.serial;

import haxe.macro.Expr;

/**
    - [ ] retries
    - [ ] timeouts
        - default 4000ms
        - `-D wwp-timeout=2500ms`
        - `@:wwp.timeout(1250ms)`
            - type meta
            - field meta
    - [ ] cancellations
        - Client side, delete cached promise waiting to be resolved.
        - Server side, responds w/ error.
    - [ ] streaming
    ---
    info
    ---
    + http://blog.carlosgaldino.com/a-critique-of-the-remote-procedure-call-paradigm-30-years-later.html
**/

enum Message {
    Invoke(name:String, id:String, arity:Int, args:Array<Expr>, timeout:Float);
    Return(name:String, id:String, arity:Int, args:Array<Expr>, timeout:Float, error:Expr);
    Notify(name:String, arity:Int, args:Array<Expr>);   // Expects no response.
}

/**
    Fields returning anything that resolves to `Void` should be treated as a
    notification.
    Otherwise its a typical send, wait [?timeout] and finish (reply|[?local|?remote] error).

    Flow:
        + --> [500ms]invoke [ready?]
        + <-- return [option<bool>]
        + == true
        // Its ok to send requests.
        + [--> invoke]*
        + [<-- return[option<Any>]]

    ---
    Considerations
    ---
    - [ ] ping? or status?
        + status could return an abstract enum.
            - Busy
            - Idle
            - Failed
            - Unknown
    - [ ] pointers? global variables? externs etc.
    
    ---
    ---
    - Use b.e/backoff `futurized` branch for retries and timeouts.
**/