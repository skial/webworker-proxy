package ww.macro;

class Utils {

    public static function unwrap<T>(f:tink.CoreApi.Promise<T>):T {
        return (null:T);
    }

    #if (hxbit && !(macro || eval))
    @:isVar public static var serializer(get, null):hxbit.Serializer;

    private static function get_serializer():hxbit.Serializer {
        if (serializer == null) {
            serializer = new hxbit.Serializer();
        }

        return serializer;
    }
    #end

}