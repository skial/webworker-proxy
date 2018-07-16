package ww.macro;

enum abstract Defines(String) to String from String {
    var JS = 'js';
    var HxBit = 'hxbit';
    var WebWorker = 'webworker';
    var WWP_Debug = 'wwp-debug';
    var WWP_DisableCheck = 'wwp-disable-check';
    var WWP_Std_Serializer = 'wwp-std-serializer';

    @:to public function defined():Bool {
        return haxe.macro.Context.defined(this);
    }
}