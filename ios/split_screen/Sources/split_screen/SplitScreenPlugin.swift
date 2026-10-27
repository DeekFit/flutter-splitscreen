import Flutter
import UIKit

public final class SplitScreenPlugin: NSObject, FlutterPlugin {
    private var observation: DuoObservation?
    private var channels: [FlutterEventChannel] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = SplitScreenPlugin()
        let methods = FlutterMethodChannel(name: "com.microsoft.flutterdualscreen/hinge_info",
                                           binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(plugin, channel: methods)
        registrar.publish(plugin)
        if #available(iOS 27.1, *) {
            let observation = DuoObservation(view: { [weak registrar] in registrar?.viewController?.view },
                                            hinge: SystemHingeProvider(), regions: SystemRegionProvider())
            plugin.observation = observation
            for (name, handler) in [("com.microsoft.flutterdualscreen/hinge_angle", observation.angle),
                                    ("split_screen/display_features", observation.layout)] {
                let channel = FlutterEventChannel(name: name, binaryMessenger: registrar.messenger())
                channel.setStreamHandler(handler)
                plugin.channels.append(channel)
            }
        } else {
            for name in ["com.microsoft.flutterdualscreen/hinge_angle", "split_screen/display_features"] {
                let channel = FlutterEventChannel(name: name, binaryMessenger: registrar.messenger())
                channel.setStreamHandler(EmptyEvents())
                plugin.channels.append(channel)
            }
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "hasHingeAngleSensor" else { result(FlutterMethodNotImplemented); return }
        guard let observation = observation else { result(false); return }
        observation.capability { result($0) }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        observation?.teardown()
        observation = nil
        for channel in channels { channel.setStreamHandler(nil) }
        channels.removeAll()
    }
}

private final class EmptyEvents: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        events(FlutterEndOfEventStream)
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? { nil }
}
