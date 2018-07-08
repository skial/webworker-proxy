package ;

import js.html.*;
import js.Syntax;
import haxe.Constraints;

class WorkerChannel extends EventTarget {

    private static var scope =
    #if webworker
        (Syntax.code('self'):DedicatedWorkerGlobalScope);
    #else
        js.Browser.window;
    #end

    public var onerror:Function = e -> scope.console.error( e );
    public var onmessage:Function = e -> {};

    public #if webworker inline #end function postMessage(message:Dynamic, ?transfer:Array<Dynamic>):Void {
        #if webworker
            scope.postMessage(message, transfer);
        #else
            
        #end
    }

}