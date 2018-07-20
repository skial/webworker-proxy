package ww.macro;

import ww.serial.*;
import haxe.io.Bytes;
import haxe.io.BytesData;

class Utils {

    public static function unwrap<T>(f:tink.CoreApi.Promise<T>):T {
        return (null:T);
    }

    #if (macro||eval)
    @:isVar public static var runners(get, null):Array<ISerial>;

    static function get_runners():Array<ISerial> {
        if (runners == null) {
            runners = [new Std(), new Js(), new HxBit()];
            runners = [for (r in runners) if (r.allowed()) r];
            for (i in 0...runners.length) runners[i].index = i;
        }
        return runners;
    }

    @:isVar public static var reverseRunners(get, null):Array<ISerial>;

    static function get_reverseRunners():Array<ISerial> {
        if (reverseRunners == null) {
            var c = runners.copy();
            c.reverse();
            reverseRunners = c;
        }
        return reverseRunners;
    }
    #end

}