package pmdb.core.ds;

import haxe.ds.Vector;
import pmdb.core.ds.tools.ArrayTools;

class IntIntHashTable {
    public var key(default, null):Int = HashKey.next();
    public var capacity(default, null):Int;
    public var growthRate:Int = GrowthRate.DOUBLE;
    public var reuseIterator:Bool = false;

    public var loadFactor(get, never):Float;
    inline function get_loadFactor():Float { return size / slotCount; }

    public var slotCount(default, null):Int;

    var mMask:Int;
    var mFree:Int = 0;
    var mSize:Int = 0;
    var mMinCapacity:Int;
    var mIterator:IntIntHashTableValIterator;
    var mTmpBuffer:NativeArray<Int>;
    var mTmpBufferSize:Int = 16;

    public function new(slotCount:Int, initialCapacity:Int = -1) {
        assert(slotCount > 0);
        assert(MathTools.isPow2(slotCount), "slotCount is not a power of 2");

        if (initialCapacity == -1)
            initialCapacity = slotCount;
        else {
            assert(initialCapacity >= 2, "minimum capacity is 2");
            assert(MathTools.isPow2(slotCount), "capacity is not a power of 2");
        }

        capacity = initialCapacity;
        mMinCapacity = initialCapacity;
        this.slotCount = slotCount;
        mMask = slotCount - 1;




        var j = 2, t = mData;
        for (i in 0...capacity) {
            t.set(j - 1, VAL_ABSENT);
            t.set(j, NULL_POINTER);
            j += 3;
        }

        t = mNext;
        for (i in 0...capacity - 1) t.set(i, i + 1);
        t.set(capacity - 1, NULL_POINTER);

        mTmpBuffer = NativeArrayTools.alloc(mTmpBufferSize);
    }
    public function getCollisionCount():Int {
        var c = 0, j, d = mData, h = mHash;
        for (i in 0...slotCount) {
            j = h.get(i);
            if (j == EMPTY_SLOT) continue;
            j = d.get(j + 2);
            while (j != NULL_POINTER) {
                j = d.get(j + 2);
                c++;
            }
        }
        return c;
    }
    public inline function getFront(key:Int):Int {
        var b = hashCode(key);
        var i = mHash.get(b);
        if (i == EMPTY_SLOT)
            return KEY_ABSENT;
        else {
            var d = mData;



            else {
                var v = KEY_ABSENT;
                var first = i, i0 = first;


                i = d.get(i + 2);

                while (i != NULL_POINTER) {

                    if (d.get(i) == key)
                    {


                        break;
                    }
                    i = d.get((i0 = i) + 2);
                }
                return v;
            }
        }
    }
    public inline function setIfAbsent(key:Int, val:Int):Bool {
        assert(val != KEY_ABSENT, "val 0x80000000 is reserved");

        var b = hashCode(key), d = mData;


        var j = mHash.get(b);
        if (j == EMPTY_SLOT) {
            if (size == capacity) {
                grow();
                d = mData;
            }

            var i = mFree * 3;
            mFree = mNext.get(mFree);




            mSize++;
            return true;
        }
        else {

            if (d.get(j) == key)
                return false;
            else {



                if (j == -1)
                    return false;
                else {
                    if (size == capacity) {
                        grow();
                        d = mData;
                    }

                    var i = mFree * 3;
                    mFree = mNext.get(mFree);

                    d.set(j + 2, i);




                    mSize++;
                    return true;
                }
            }
        }
    }
    public function rehash(slotCount:Int):IntIntHashTable {
        assert(MathTools.isPow2(slotCount), "slotCount is not a power of 2");

        if (this.slotCount == slotCount) return this;

        var t = new IntIntHashTable(slotCount, capacity);






        mHash = t.mHash;
        mData = t.mData;
        mNext = t.mNext;

        this.slotCount = slotCount;
        mMask = t.mMask;
        mFree = t.mFree;
        return this;
    }
    public inline function remap(key:Int, val:Int):Bool {
        var i = mHash.get(hashCode(key));
        if (i == EMPTY_SLOT)
            return false;
        else {
            var d = mData;



            else {


                return i != NULL_POINTER;
            }
        }
    }
    public inline function extract(key:Int):Int {
        var b = hashCode(key), h = mHash;
        var i = h.get(b);
        if (i == EMPTY_SLOT)
            return IntIntHashTable.KEY_ABSENT;
        else {
            var d = mData;

            if (key == d.get(i)) {
                var val = d.get(i + 1);

                if (d.get(i + 2) == NULL_POINTER)
                    h.set(b, EMPTY_SLOT);
                else
                    h.set(b, d.get(i + 2));

                var j = Std.int(i / 3);
                mNext.set(j, mFree);
                mFree = j;




                mSize--;
                return val;
            }
            else {
                var i0 = i;

                i = d.get(i + 2);

                var val = IntIntHashTable.KEY_ABSENT;

                while (i != NULL_POINTER) {


                }

                if (val != IntIntHashTable.KEY_ABSENT) {
                    d.set(i0 + 2, d.get(i + 2));

                    var j = Std.int(i / 3);
                    mNext.set(j, mFree);
                    mFree = j;




                    mSize--;
                    return val;
                }
                else
                    return IntIntHashTable.KEY_ABSENT;
            }
        }
    }
    public function toKeyArray():Array<Int> {
        if (isEmpty()) return [];

        var out = ArrayTools.alloc(size);
        var j = 0, d = mData;
        for (i in 0...capacity) {


        }
        return out;
    }
#if !no_tostring
    public function toString():String {
        var b = new StringBuf();
        b.add(Printf.format('[ IntIntHashTable size=$size capacity=$capacity load=%.2f', [loadFactor]));
        if (isEmpty()) {
            b.add(" ]");
            return b.toString();
        }
        b.add("\n");
        var max = 0.;
        for (key in keys()) max = Math.max(max, key);
        var i = 1;
        while (max != 0) {
            i++;
            max = Std.int(max / 10);
        }
        var args = new Array<Dynamic>();
        var fmt = '  %- $ {
            i}d -> %s\n';

        var keys = [for (key in keys()) key];
        keys.sort(function(u, v) return u - v);
        i = 1;
        var k = keys.length;
        var j = 0;
        var c = 1;
        inline function print(key:Int) {
            args[0] = key;
            if (c > 1) {
                var tmp = [];
                getAll(key, tmp);
                args[1] = tmp.join(",");
            }
            else
                args[1] = get(key);
            b.add(Printf.format(fmt, args));
        }
        while (i < k) {
            if (keys[j] == keys[i])
                c++;
            else {
                print(keys[j]);
                j = i;
                c = 1;
            }
            i++;
        }
        print(keys[j]);

        b.add("]");
        return b.toString();
    }
    #end

    public function has(val:Int):Bool {
        assert(val != VAL_ABSENT, "val 0x80000000 is reserved");

        var exists = false, d = mData;
        for (i in 0...capacity) {
            var v = d.get((i * 3) + 1);
            if (v == val) {
                exists = true;
                break;
            }
        }
        return exists;
    }
    public inline function hasKey(key:Int):Bool {
        var i = mHash.get(hashCode(key));
        if (i == EMPTY_SLOT)
            return false;
        else {
            var d = mData;



            else {
                var exists = false;


                return exists;
            }
        }
    }
    public function count(key:Int):Int {
        var c = 0;
        var i = mHash.get(hashCode(key));
        if (i == EMPTY_SLOT)
            return c;
        else {
            var d = mData;



            return c;
        }
    }
    public inline function get(key:Int):Int {
        var i = mHash.get(hashCode(key));
        if (i == EMPTY_SLOT)
            return KEY_ABSENT;
        else {
            var d = mData;


            else {
                var v = KEY_ABSENT;


                return v;
            }
        }
    }
    public function getAll(key:Int, out:Array<Int>):Int {
        var i = mHash.get(hashCode(key));
        if (i == EMPTY_SLOT)
            return 0;
        else {
            var c = 0;
            var d = mData;


            return c;
        }
    }
    public function hasPair(key:Int, val:Int):Bool {
        assert(val != KEY_ABSENT, "val 0x80000000 is reserved");

        var i = mHash.get(hashCode(key));
        if (i == EMPTY_SLOT)
            return false;
        else {
            var d = mData;



            return false;
        }
    }
    public function unsetPair(key:Int, val:Int):Bool {
        assert(val != KEY_ABSENT, "val 0x80000000 is reserved");

        var b = hashCode(key), h = mHash;
        var i = h.get(b);
        if (i == EMPTY_SLOT)
            return false;
        else {
            var d = mData;

            if (key == d.get(i) && val == d.get(i + 1))
            {

                if (d.get(i + 2) == NULL_POINTER)
                    h.set(b, EMPTY_SLOT);
                else
                    h.set(b, d.get(i + 2));

                var j = Std.int(i / 3);
                mNext.set(j, mFree);
                mFree = j;




                mSize--;
                return true;
            }
            else {
                var exists = false;

                var i0 = i;

                i = d.get(i + 2);

                while (i != NULL_POINTER) {


                }

                if (exists) {
                    d.set(i0 + 2, d.get(i + 2));

                    var j = Std.int(i / 3);
                    mNext.set(j, mFree);
                    mFree = j;




                    --mSize;
                    return true;
                }
                else
                    return false;
            }
        }
    }
    public inline function set(key:Int, val:Int):Bool {
        assert(val != KEY_ABSENT, "val 0x80000000 is reserved");

        if (size == capacity) grow();

        var d = mData, h = mHash;
        var i = mFree * 3;
        mFree = mNext.get(mFree);




        var b = hashCode(key);



        else {



            while (t != NULL_POINTER) {


            }


            d.set(j + 2, i);

            mSize++;
            return first;
        }
    }
    public inline function unset(key:Int):Bool {
        var b = hashCode(key), h = mHash;
        var i = h.get(b);
        if (i == EMPTY_SLOT)
            return false;
        else {
            var d = mData;


            if (key == d.get(i))
            {

                if (d.get(i + 2) == NULL_POINTER)
                    h.set(b, EMPTY_SLOT);
                else
                    h.set(b, d.get(i + 2));

                var j = Std.int(i / 3);
                mNext.set(j, mFree);
                mFree = j;




                mSize--;
                return true;
            }
            else {
                var exists = false;

                var i0 = i;

                i = d.get(i + 2);

                while (i != NULL_POINTER) {


                }

                if (exists) {
                    d.set(i0 + 2, d.get(i + 2));

                    var j = Std.int(i / 3);
                    mNext.set(j, mFree);
                    mFree = j;




                    mSize--;
                    return true;
                }
                else
                    return false;
            }
        }
    }
    public function toValSet():Set<Int> {
        var s = new IntHashSet(capacity), d = mData;
        for (i in 0...capacity) {
            var v = d.get((i * 3) + 1);
            if (v != VAL_ABSENT) s.set(v);
        }
        return s;
    }
    public function toKeySet():Set<Int> {
        var s = new IntHashSet(capacity), d = mData;
        for (i in 0...capacity) {
            var v = d.get((i * 3) + 1);
            if (v != VAL_ABSENT) {
                s.set(d.get(i * 3));
            }
        }
        return s;
    }
    public function keys():Itr<Int> {
        return new IntIntHashTableKeyIterator(this);
    }
    public function pack():IntIntHashTable {
        if (capacity == mMinCapacity) return this;

        capacity = MathTools.max(size, mMinCapacity);

        var src = mData, dst;
        var e = 0, t = mHash;


        dst = NativeArrayTools.alloc(capacity * 3);

        var j = 2;
        for (i in 0...capacity) {
            dst.set(j - 1, VAL_ABSENT);
            dst.set(j, NULL_POINTER);
            j += 3;
        }




        var n = mNext;
        for (i in 0...capacity - 1) n.set(i, i + 1);
        n.set(capacity - 1, NULL_POINTER);
        mFree = -1;
        return this;
    }
    public inline function iter(f:Int->Int->Void):IntIntHashTable {
        assert(f != null);
        var d = mData, j, v;
        for (i in 0...capacity) {
            j = i * 3;
            v = d.get(j + 1);
            if (v != VAL_ABSENT) f(d.get(j), v);
        }
        return this;
    }

    inline function hashCode(x:Int):Int {
        return (x * 73856093) & mMask;
    }

    function grow() {
        var oldCapacity = capacity;
        capacity = GrowthRate.compute(growthRate, capacity);

        var t;

        #if alchemy
        mNext.resize(capacity);
        mData.resize(capacity * 3);
        #else
        t = NativeArrayTools.alloc(capacity);
        mNext.blit(0, t, 0, oldCapacity);
        mNext = t;
        t = NativeArrayTools.alloc(capacity * 3);
        mData.blit(0, t, 0, oldCapacity * 3);
        mData = t;
        #end

        t = mNext;
        for (i in oldCapacity - 1...capacity - 1) t.set(i, i + 1);
        t.set(capacity - 1, NULL_POINTER);
        mFree = oldCapacity;

        var j = oldCapacity * 3 + 2;
        t = mData;
        for (i in 0...capacity - oldCapacity) {


            j += 3;
        }
    }

    public var size(get, never):Int;
    inline function get_size():Int {
        return mSize;
    }
    public function free() {



        mHash = null;
        mData = null;
        mNext = null;
        if (mIterator != null) {
            mIterator.free();
            mIterator = null;
        }
        mTmpBuffer = null;
    }
    public inline function contains(val:Int):Bool {
        return has(val);
    }
    public function remove(val:Int):Bool {
        assert(val != KEY_ABSENT, "val 0x80000000 is reserved");

        var c = 0;
        var keys = mTmpBuffer;
        var max = mTmpBufferSize;
        var d = mData, j;




        for (i in 0...c) unset(keys.get(i));
        return c > 0;
    }
    public function clear(gc:Bool = false) {



        var j = 2, t = mData;
        for (i in 0...capacity) {
            t.set(j - 1, VAL_ABSENT);
            t.set(j    , NULL_POINTER);
            j += 3;
        }

        t = mNext;
        for (i in 0...capacity - 1) t.set(i, i + 1);
        t.set(capacity - 1, NULL_POINTER);

        mFree = 0;
        mSize = 0;
    }
    public function iterator():Itr<Int> {
        if (reuseIterator) {
            if (mIterator == null)
                mIterator = new IntIntHashTableValIterator(this);
            else
                mIterator.reset();
            return mIterator;
        }
        else
            return new IntIntHashTableValIterator(this);
    }
    public inline function isEmpty():Bool {
        return size == 0;
    }
    public function toArray():Array<Int> {

        if (isEmpty()) return [];

        var out = ArrayTools.alloc(size);
        var j = 0, v, d = mData;
        for (i in 0...capacity) {
            v = d.get((i * 3) + 1);
            if (v != VAL_ABSENT) out[j++] = v;
        }
        return out;
    }

    public function clone(byRef:Bool = true, copier:Int->Int = null):Collection<Int> {

        var c = new IntIntHashTable(slotCount, capacity);
        c.mMask = mMask;
        c.slotCount = slotCount;
        c.capacity = capacity;
        c.mFree = mFree;
        c.mSize = size;
        return c;
    }

    public static inline var KEY_ABSENT = MathTools.INT32_MIN;
    public static inline var VAL_ABSENT = MathTools.INT32_MIN;
    public static inline var EMPTY_SLOT = -1;
    public static inline var NULL_POINTER = -1;
}

@:access(polygonal.ds.IntIntHashTable)
@:dox(hide)
class IntIntHashTableValIterator implements polygonal.ds.Itr<Int> {
    var mObject:IntIntHashTable;
    var mI:Int;
    var mS:Int;

    var mData:<Int>;

    public function new(x:IntIntHashTable) {
        mObject = x;
        mData = x.mData;
        mI = 0;
        mS = x.capacity;
        scan();
    }

    public function free() {
        mObject = null;
        mData = null;
    }

    public function reset():Itr<Int> {
        mData = mObject.mData;
        mI = 0;
        mS = mObject.capacity;
        scan();
        return this;
    }

    public inline function hasNext():Bool {
        return mI < mS;
    }

    public inline function next():Int {
        var val = mData.get((mI++ * 3) + 1);
        scan();
        return val;
    }

    public function remove() {
        throw "unsupported operation";
    }

    function scan() {
        while ((mI < mS) && (mData.get((mI * 3) + 1) == IntIntHashTable.VAL_ABSENT)) mI++;
    }
}

@:access(pmdb.core.ds.IntIntHashTable)
@:dox(hide)
class IntIntHashTableKeyIterator implements polygonal.ds.Itr<Int> {
    var mObject:IntIntHashTable;
    var mI:Int;
    var mS:Int;


    var mData:NativeArray<Int>;

    public function new(x:IntIntHashTable) {
        mObject = x;
        mData = x.mData;
        mI = 0;
        mS = x.capacity;
        scan();
    }

    public function free() {
        mObject = null;
        mData = null;
    }

    public function reset():Itr<Int> {
        mData = mObject.mData;
        mI = 0;
        mS = mObject.capacity;
        scan();
        return this;
    }

    public inline function hasNext():Bool {
        return mI < mS;
    }

    public inline function next():Int {
        var key = mData.get((mI++ * 3));
        scan();
        return key;
    }

    public function remove() {
        throw "unsupported operation";
    }
    function scan() {
        while ((mI < mS) && (mData.get((mI * 3) + 1) == IntIntHashTable.VAL_ABSENT)) mI++;
    }
}
