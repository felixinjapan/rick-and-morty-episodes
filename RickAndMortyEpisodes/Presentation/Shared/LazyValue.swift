/// Builds a value on first use and keeps it. `State(initialValue:)` evaluates its argument on every
/// `View.init`, though it keeps only the first result. Holding one of these in `@State` means a view
/// that is re-initialized creates a closure, not a view model.
@MainActor
final class LazyValue<Value> {
    private var make: (() -> Value)?
    private var built: Value?

    init(_ make: @escaping () -> Value) {
        self.make = make
    }

    var value: Value {
        if let built { return built }
        let value = make!()
        built = value
        make = nil
        return value
    }
}
