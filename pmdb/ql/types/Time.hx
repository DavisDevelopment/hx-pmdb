package pmdb.ql.types;

import Date;

using DateTools;
using pm.Numbers;

abstract Time(Date) {
    public static function is(x: Dynamic):Bool return (x is Date);

    public inline function getHours():Int return this.getHours();
    public inline function getMinutes():Int return this.getMinutes();
    public inline function getSeconds():Int return this.getSeconds();
    @:to @:native('_tup_')
    public inline function tuple():Array<Int> return [getHours(), getMinutes(), getSeconds()];
}