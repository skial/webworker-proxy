package ww.serial;

import haxe.io.Bytes;
import haxe.io.BytesData;

#if (macro||eval)
import ww.macro.Info;
import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;
#end

class Std #if (macro||eval) implements ISerial #end {

    #if !(macro||eval)
    // @see https://github.com/runspired/webworker-performance/blob/master/public/workers/transfer.js
    public static inline function createStdTransferable(value:Any):BytesData {
        return Bytes.ofString(haxe.Serializer.run(value)).getData();
    }

    public static inline function readStdTransferable<T>(value:BytesData):T {
        return haxe.Unserializer.run(Bytes.ofData(value).toString());
    }
    #end

    #if (macro||eval)
    public var index:Int = 0;
    public var define:Defines;
    
    public function new(d:String = 'std') {
        define = d;
    }

    public function allowed():Bool return true;

    public function detectIllegalTypes(type:Type, pos:Position):Void {

    }

    public function detectIllegalClassField(field:ClassField, isStatic:Bool = false):Void {
        
    }

    public function detectIllegalEnumField(field:EnumField):Void {
        
    }

    public function timeStamp():ExprOf<Float> {
        return macro Math.random() + haxe.Timer.stamp() * Math.random();
    }

    public function encode(expr:Expr, info:Info):Expr {
        return macro @:std $expr;
    }

    public function decode(expr:Expr, info:Info):Expr {
        return macro @:std $expr;
    }

    public function send(data:Expr, info:Info):Expr {
        throw 'Not Implemented.';
    }

    public function reply(data:Expr, info:Info):Expr {
        throw 'Not Implemented.';
    }

    #end

}