/// Delivery lifecycle for ESP32 RF chat messages (outgoing on this device).
enum Esp32DeliveryState {
  sending,
  sent,
  received,
  seen,
  failed,
}
