package ww.macro;

class Utils {

    public static function unwrap<T>(f:tink.CoreApi.Promise<T>):T {
        return (null:T);
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

}