package ww.macro;

enum abstract Defines(String) to String {
    var HxBit = 'hxbit';
    var WebWorker = 'webworker';
    var WWP_Std_Serializer = 'wwp-std-serializer';
    var WWP_Debug = 'wwp-debug';

    @:to public function defined():Bool {
        return haxe.macro.Context.defined(this);
    }
}