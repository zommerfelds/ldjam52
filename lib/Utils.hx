// This file is part of https://github.com/zommerfelds/herbal-tea-framework
// Avoid making game-specific changes to this file. Contribute back if possible!
import h2d.col.IPoint;
import h2d.col.Point;
import haxe.Constraints.IMap;

using ObjExt;
using StringTools;

/** A 2D integer point that can be put in a HashMap. **/
class Point2d {
	public function new(x = 0, y = 0) {
		this.x = x;
		this.y = y;
	}

	public var x:Int;
	public var y:Int;

	// Can't go too high to have perfect pairing (probably good to stay under a magnitude of 5000).
	public function hashCode() {
		// https://gist.github.com/TheGreatRambler/048f4b38ca561e6566e0e0f6e71b7739
		var xx = x >= 0 ? x * 2 : x * -2 - 1;
		var yy = y >= 0 ? y * 2 : y * -2 - 1;
		return (xx >= yy) ? (xx * xx + xx + yy) : (yy * yy + xx);
	}

	public function toString() {
		return '$x/$y';
	}
}

typedef Int2d = {x:Int, y:Int}
typedef Float2d = {x:Float, y:Float}
typedef AxialPoint = Int2d // TODO: remove?

class Utils {
	public static function floatToStr(n:Float, prec = 3, rpad = 0) {
		var neg = false;
		if (n < 0) {
			neg = true;
			n = -n;
		}
		n = Math.round(n * Math.pow(10, prec));
		var str = '' + n;
		var len = str.length;
		var r;
		if (len <= prec) {
			while (len < prec) {
				str = '0' + str;
				len++;
			}
			r = '0.' + str;
		} else {
			r = str.substr(0, str.length - prec) + '.' + str.substr(str.length - prec);
		}
		if (rpad > 0) {
			r = r.rpad(' ', rpad);
		}
		return (neg ? '-' : '') + r;
	}

	public static function point(p) { // Make Float2d?
		return new Point(p.x, p.y);
	}

	public static function toAxialPoint(p):AxialPoint {
		return {x: p.x, y: p.y};
	}

	public static function toIPoint(p) {
		return new IPoint(p.x, p.y);
	}

	public static inline function pointToStr(p:Float2d) {
		return floatToStr(p.x) + "/" + floatToStr(p.y);
	}

	public static inline function iPointToStr(p:{x:Int, y:Int}) {
		return p.x + "/" + p.y;
	}

	public static function sign(x:Float) {
		return switch (x) {
			case _ if (x > 0):
				1.0;
			case _ if (x < 0):
				-1.0;
			case _:
				0.0;
		}
	}

	/** Same as hxd.Math.valueMove(), but for vectors. **/
	public static function moveTowards(p:Point, target:Point, maxDistanceDelta:Float) {
		final d = target.sub(p);
		final length = d.length();
		if (length <= maxDistanceDelta) {
			return target;
		}
		return p.add(d.multiply(maxDistanceDelta / length));
	}

	public static function angle(p:Float2d) {
		return Math.atan2(p.y, p.x) + Math.PI * 0.5;
	}

	public static function direction(angle:Float) {
		return new Point(Math.cos(angle), Math.sin(angle));
	}

	/** Returns the signed shortest angle difference from angle1 to angle2. */
	public static function angularDiff(angle1:Float, angle2:Float):Float {
		var r = (angle1 - angle2) % (Math.PI * 2);
		if (r > Math.PI) {
			r -= Math.PI * 2;
		} else if (r < -Math.PI) {
			r += Math.PI * 2;
		}
		return r;
	}

	/** Returns the shortest (signed) angle from v1 to v2. **/
	public static function angleBetween(v1:Point, v2:Point):Float {
		return angularDiff(Math.atan2(v1.y, v1.x), Math.atan2(v2.y, v2.x));
	}

	/** Normalizes the angle to be in [0, 2*Pi[ */
	public static inline function normAngle(a:Float):Float {
		return hxd.Math.ufmod(a, Math.PI * 2);
	}

	public static inline function normAtan2(y:Float, x:Float):Float {
		return normAngle(Math.atan2(y, x));
	}

	public static function className<T>(t:T) {
		return Type.getClassName(Type.getClass(t));
	}

	public static function distToLineSegment(p:Point, l0:Point, l1:Point) {
		// From https://stackoverflow.com/a/1501725/3810493
		final d2 = l0.distanceSq(l1);
		if (d2 == 0.0)
			return p.distance(l0); // l0 == l1 case
		// Consider the line extending the segment, parameterized as v + t (w - v).
		// We find projection of point p onto the line.
		// It falls where t = [(p-v) . (w-v)] / |w-v|^2
		// We clamp t from [0,1] to handle points outside the segment vw.
		final t = Math.max(0, Math.min(1, p.sub(l0).dot(l1.sub(l0)) / d2));
		final projection = l0.add(l1.sub(l0).multiply(t)); // Projection falls on the segment
		return p.distance(projection);
	}

	public static final sqrt3 = Math.sqrt(3);

	public inline static function axialToCartesian(x:Int, y:Int, radius:Float) {
		return new Point(x * radius * sqrt3 + y * radius * sqrt3 * 0.5, y * radius * 1.5);
	}

	public static function cartesianToAxial(x:Float, y:Float, radius:Float) {
		var q = (x / sqrt3 - y / 3) / radius;
		var r = 2 / 3 * y / radius;

		// Cube coordinates
		var rx = Math.round(q);
		var ry = Math.round(r);
		var rz = Math.round(-q - r);

		var xDiff = Math.abs(rx - q);
		var yDiff = Math.abs(ry - r);
		var zDiff = Math.abs(rz - (-q - r));

		if (xDiff > yDiff && xDiff > zDiff) {
			rx = -ry - rz;
		} else if (yDiff > zDiff) {
			ry = -rx - rz;
		}

		return new IPoint(rx, ry);
	}

	public static inline function left(p) {
		return {x: p.x - 1, y: p.y};
	}

	public static inline function right(p) {
		return {x: p.x + 1, y: p.y};
	}

	public static inline function topLeft(p) {
		return {x: p.x, y: p.y - 1};
	}

	public static inline function topRight(p) {
		return {x: p.x + 1, y: p.y - 1};
	}

	public static inline function bottomLeft(p) {
		return {x: p.x - 1, y: p.y + 1};
	}

	public static inline function bottomRight(p) {
		return {x: p.x, y: p.y + 1};
	}

	public static inline function neighbors(p) {
		return [left(p), right(p), topLeft(p), topRight(p), bottomLeft(p), bottomRight(p)];
	}

	/** Returns a string such as 8h3m10s. Precision is one of seconds: 0, minutes: 1, hours: 2, days: 3 **/
	public static function durationToStr(miliseconds:Float, precision = 0) {
		function roundLast(f) {
			final r = Math.round(f);
			return r == 0 ? 1 : r;
		}
		var r = "";
		final days = Std.int(miliseconds / (24 * 60 * 60 * 1000));
		if (days > 0 || r != "") {
			r += days + 'd';
			miliseconds -= days * 24 * 60 * 60 * 1000;
		}
		if (precision <= 2) {
			final hoursFloat = miliseconds / (60 * 60 * 1000);
			final hours = if (precision == 2 && r == "") roundLast(hoursFloat); else Std.int(hoursFloat);
			if (hours > 0 || r != "") {
				r += hours + 'h';
				miliseconds -= hours * 60 * 60 * 1000;
			}
		}
		if (precision <= 1) {
			final minutesFloat = miliseconds / (60 * 1000);
			final minutes = if (precision == 1 && r == "") roundLast(minutesFloat); else Std.int(minutesFloat);
			if (minutes > 0 || r != "") {
				r += minutes + 'm';
				miliseconds -= minutes * 60 * 1000;
			}
		}
		if (precision <= 0) {
			final secondsFloat = miliseconds / (1000);
			final seconds = if (precision == 0 && r == "") roundLast(secondsFloat); else Std.int(secondsFloat);
			if (seconds > 0 || r != "") {
				r += seconds + 's';
				miliseconds -= seconds * 1000;
			}
		}
		return r;
	}

	public static function maxBy<A>(it:Iterable<A>, f:A->Int):Null<A> {
		var max:Null<A> = null;
		var maxVal = -1;
		for (e in it) {
			final val = f(e);
			if (max == null || val > maxVal) {
				max = e;
				maxVal = val;
			}
		}
		return max;
	}

	public static function sum(it:Iterable<Float>):Float {
		var sum = 0.0;
		for (e in it) {
			sum += e;
		}
		return sum;
	}

	public static function posUpdated(obj:h2d.Object) {
		// Tween is not smart enough to call the setter.
		obj.x = obj.x;
	}

	/** Tweening for Heaps objects.
		Careful with onComplete() as it might get dropped if the tween is overwritten. Use `after` instead.
	**/
	public static function tween(obj, time:Float, properties:Dynamic, overwrite = true, after = null) {
		if (after != null) {
			motion.Actuate.timer(time).onComplete(after);
		}
		return motion.Actuate.tween(obj, time, properties, overwrite)
			.onUpdate(() -> posUpdated(obj))
			.onComplete(() -> posUpdated(obj));
	}

	/** Returns a new velocity, with drag applied. **/
	public static function applyDrag(velocity:Point, linearCoefficient:Float, quadraticCoeficcient:Float, timeStep:Float) {
		return velocity.multiply(1 - (linearCoefficient + velocity.length() * quadraticCoeficcient) * timeStep);
	}

	public static function toArray<A>(iter:Iterator<A>):Array<A> {
		final array = new Array<A>();
		while (iter.hasNext()) {
			array.push(iter.next());
		}
		return array;
	}

	public static function mapIterator<A, B>(iter:Iterator<A>, func:A->B):Iterator<B> {
		return {
			next: () -> func(iter.next()),
			hasNext: iter.hasNext,
		};
	}

	public static function addInteractive(obj:h2d.Object, ?padding:Float) {
		if (padding == null) {
			// Note: the default padding ignores potential scaling of the parents.
			padding = Gui.scale(15) / obj.scaleX;
		}
		final interactive = new h2d.Interactive(
			obj.getBounds(obj).width + 2 * padding,
			obj.getBounds(obj).height + 2 * padding,
			obj
		);
		interactive.x = -padding;
		interactive.y = -padding;
		return interactive;
	}

	/** An opinionated, somewhat generic and hacky toString() function. **/
	public static function anythingToString(any:Dynamic) {
		final buf = new StringBuf();
		function rec(obj, indent):Void {
			if (obj == null) {
				buf.add('null');
			} else if (Std.isOfType(obj, String)) {
				buf.add(obj.toString());
			} else if (Std.isOfType(obj, Point)) {
				buf.add(pointToStr({x: obj.x, y: obj.y}));
			} else if (Std.isOfType(obj, Array)) {
				final a = cast(obj, Array<Dynamic>);
				buf.add('[');
				final it = a.iterator();
				for (e in it) {
					rec(e, indent);
					if (it.hasNext()) {
						buf.add(', ');
					}
				}
				buf.add(']');
			} else if (Std.isOfType(obj, IMap)) {
				final map = cast(obj, IMap<Dynamic, Dynamic>);
				final firstVal = map.iterator().hasNext() ? map.iterator().next() : null;
				if (Std.isOfType(firstVal, Int) || Std.isOfType(firstVal, Bool) || Std.isOfType(firstVal, Float)
					|| Std.isOfType(firstVal, String)) {
					buf.add('Map{');
					final it = map.keyValueIterator();
					for (i in it) {
						buf.add('${i.key}=');
						rec(i.value, indent);
						if (it.hasNext()) {
							buf.add(', ');
						}
					}
					buf.add('}');
				} else {
					buf.add('Map{\n');
					for (i in map.keyValueIterator()) {
						buf.add('$indent  ${i.key}: ');
						rec(i.value, indent + '  ');
						buf.add('\n');
					}
					buf.add('$indent}');
				}
			} else if (Reflect.isObject(obj) && Type.getClass(obj) != null) {
				if (Type.getClassName(Type.getClass(obj)) == 'Date') {
					buf.add(DateTools.format(cast obj, "%Y-%m-%d_%H:%M:%S"));
				} else {
					buf.add(Type.getClassName(Type.getClass(obj)) + ':\n');
					for (f in Type.getInstanceFields(Type.getClass(obj))) {
						final value = Reflect.getProperty(obj, f);
						if (Reflect.isFunction(value))
							continue;
						buf.add('$indent  $f: ');
						rec(value, indent + '  ');
						buf.add("\n");
					}
				}
			} else if (Reflect.isObject(obj)) {
				buf.add('{');
				final it = Reflect.fields(obj).iterator();
				for (f in it) {
					buf.add('$f: ');
					final value = Reflect.getProperty(obj, f);
					rec(value, indent + '  ');
					if (it.hasNext()) {
						buf.add(', ');
					}
				}
				buf.add('}');
			} else {
				buf.add(obj.toString());
			}
			return;
		}
		rec(any, '');
		return buf.toString();
	}
}