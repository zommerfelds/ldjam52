/** A dummy object which runs an arbitrary update function in the game loop.
	Can be useful for adding logic to the game without having to write a custom update loop. **/
class FuncObject extends h2d.Object {
	final updateFunc:() -> Void;

	public function new(updateFunc, parent) {
		this.updateFunc = updateFunc;
		super(parent);
	}

	override function sync(ctx:h2d.RenderContext) {
		updateFunc();
		super.sync(ctx);
	}
}