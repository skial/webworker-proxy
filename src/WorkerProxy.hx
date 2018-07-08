package ;

import haxe.Constraints;

typedef WorkerLike = {
    var onmessage:Function;
	var onerror:Function;
    function postMessage(message:Dynamic, ?transfer:Array<Dynamic>):Void;
    
    //@:overload(function(type:String, listener:Function, ?options:{?capture:Bool, ?once:Bool, ?passive:Bool}):Void {})
    function addEventListener(type:String, listener:Function, ?useCapture:Bool):Void;
    
    //@:overload(function(type:String, listener:Function, ?options:{?capture:Bool, passive:Bool}):Void {})
    function removeEventListener(type:String, listener:Function, ?useCapture:Bool):Void;
    function dispatchEvent(event:js.html.Event):Bool;
}

#if !(macro || eval)
@:genericBuild( ww.macro.WorkerProxy.build() )
#end
class WorkerProxy<T:WorkerLike> {}