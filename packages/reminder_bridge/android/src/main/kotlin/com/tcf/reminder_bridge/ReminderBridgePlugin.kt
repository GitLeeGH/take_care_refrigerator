package com.tcf.reminder_bridge
import io.flutter.embedding.engine.plugins.FlutterPlugin
class ReminderBridgePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ReminderLedgerChannel.register(binding.applicationContext, binding.binaryMessenger)
        OneShotReceiptChannel.register(binding.applicationContext, binding.binaryMessenger)
        ReminderWork.register(binding.applicationContext, binding.binaryMessenger)
        LocalExpiryReminders.register(binding.applicationContext, binding.binaryMessenger)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
