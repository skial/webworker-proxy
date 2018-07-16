package ww.macro;

import ww.check.*;
import haxe.io.Bytes;
import haxe.io.BytesData;

class Utils {

    public static function unwrap<T>(f:tink.CoreApi.Promise<T>):T {
        return (null:T);
    }

    // @see https://github.com/runspired/webworker-performance/blob/master/public/workers/transfer.js
    public static inline function createStdTransferable(value:Any):BytesData {
        return Bytes.ofString(haxe.Serializer.run(value)).getData();
    }

    public static inline function readStdTransferable<T>(value:BytesData):T {
        return haxe.Unserializer.run(Bytes.ofData(value).toString());
    }

    #if (hxbit && !(macro || eval))
    @:isVar public static var hxbit(get, null):hxbit.Serializer;

    private static function get_hxbit():hxbit.Serializer {
        if (hxbit == null) {
            hxbit = new hxbit.Serializer();
        }

        return hxbit;
    }
    #end

    #if (macro||eval)
    @:isVar public static var runners(get, null):Array<IRunner>;
    @:isVar public static var checkers(get, null):Array<ICheck>;

    static function get_runners():Array<IRunner> {
        if (runners == null) {
            runners = [new Std(), new Js()];
            runners = [for (r in runners) if (r.allowed()) r];
        }
        return runners;
    }

    static function get_checkers():Array<ICheck> {
        if (checkers == null) {
            checkers = [for (r in runners) r];
        }
        return checkers;
    }
    #end

}