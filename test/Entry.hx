package ;

import WorkerProxy;
import WorkerChannel;
import js.html.Worker;

using tink.CoreApi;

class Entry {

    public static function main() {
        var proxy = new WorkerProxy<Test>(
            #if !webworker
            new Worker('ww.js')
            #else
            new Test()
            #end
        );
        #if !webworker
        for (i in [8, 9, 10]) 
            proxy.sum(10, i)
            .next( v -> 'Sum total: $v' )
            .handle( tracer );

        for (i in [8, 9, 10]) 
            proxy.multi(10, i)
            .next( v -> 'Multi total: $v' )
            .handle( tracer );

        for (i in [1, 2, 3]) 
            (proxy.a = i)
            .next( i -> 'proxy.a == $i' )
            .handle( tracer );

        for (i in 0...4) 
            proxy.b.next( v -> 'proxy.b == $v' )
            .handle( tracer );
        #end
    }

    static function tracer(o:Outcome<String, Error>) switch o{
        case Success(v): trace(v);
        case Failure(e): trace(e);
    }

}

class Test extends WorkerChannel {

    public static function mult(a:Int, b:Int):Int {
        return a * b;
    }

    public var a:Int;
    public var b(get, null):Int;

    inline function get_b() return 10;

    public function new() {}

    public function echo(say:String):String {
        return say;
    }

    public function sum(a:Int, b:Int):Int {
        return a + b;
    }

    public function multi(a:Int, b:Int) return mult(a, b);

}