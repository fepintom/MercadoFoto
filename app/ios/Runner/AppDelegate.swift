import Flutter
import MapKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OkMapKitPlugin") {
      OkMapKitPlugin.register(with: registrar)
    }
  }
}

/// Funciones nativas de Apple Maps para OkVenta (canal "okventa/mapkit"):
///  - buscar: lugares y direcciones con el buscador de Apple (MKLocalSearch)
///  - ruta: ruta, distancia y tiempo en auto o a pie (MKDirections)
///  - lookAround: vista a nivel de calle (iOS 16+)
///  - estilo: modo claro/oscuro de OkVenta y qué lugares de Apple mostrar
///    en todos los mapas abiertos.
class OkMapKitPlugin: NSObject, FlutterPlugin {
  private var oscuro: Bool?
  private var lugares: String = "todos"

  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(name: "okventa/mapkit", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(OkMapKitPlugin(), channel: canal)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let a = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "buscar": buscar(a, result)
    case "ruta": ruta(a, result)
    case "lookAround": lookAround(a, result)
    case "foto": foto(a, result)
    case "direccion": direccion(a, result)
    case "estilo":
      if let o = a["oscuro"] as? Bool { oscuro = o } else { oscuro = nil }
      lugares = a["lugares"] as? String ?? "todos"
      aplicarEstilo()
      // Por si el mapa recién se está montando.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.aplicarEstilo() }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.aplicarEstilo() }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func coord(_ a: [String: Any], _ lat: String, _ lng: String) -> CLLocationCoordinate2D? {
    guard let la = (a[lat] as? NSNumber)?.doubleValue,
          let ln = (a[lng] as? NSNumber)?.doubleValue else { return nil }
    return CLLocationCoordinate2D(latitude: la, longitude: ln)
  }

  // MARK: Buscar

  private func buscar(_ a: [String: Any], _ result: @escaping FlutterResult) {
    let texto = (a["texto"] as? String ?? "").trimmingCharacters(in: .whitespaces)
    if texto.isEmpty { result([]); return }
    let req = MKLocalSearch.Request()
    req.naturalLanguageQuery = texto
    if let c = coord(a, "lat", "lng") {
      req.region = MKCoordinateRegion(center: c, latitudinalMeters: 40000, longitudinalMeters: 40000)
    }
    req.resultTypes = [.address, .pointOfInterest]
    MKLocalSearch(request: req).start { resp, _ in
      let items = (resp?.mapItems ?? []).prefix(12).map { it -> [String: Any] in
        let p = it.placemark
        return [
          "nombre": it.name ?? p.name ?? "",
          "direccion": p.title ?? "",
          "lat": p.coordinate.latitude,
          "lng": p.coordinate.longitude,
          "categoria": it.pointOfInterestCategory?.rawValue ?? "",
        ]
      }
      DispatchQueue.main.async { result(Array(items)) }
    }
  }

  // MARK: Ruta

  private func ruta(_ a: [String: Any], _ result: @escaping FlutterResult) {
    guard let o = coord(a, "olat", "olng"), let d = coord(a, "dlat", "dlng") else {
      result(nil); return
    }
    let req = MKDirections.Request()
    req.source = MKMapItem(placemark: MKPlacemark(coordinate: o))
    req.destination = MKMapItem(placemark: MKPlacemark(coordinate: d))
    req.transportType = (a["modo"] as? String) == "pie" ? .walking : .automobile
    MKDirections(request: req).calculate { resp, _ in
      guard let r = resp?.routes.first else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let n = r.polyline.pointCount
      var cs = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: n)
      r.polyline.getCoordinates(&cs, range: NSRange(location: 0, length: n))
      let paso = max(1, n / 400)
      var puntos: [[Double]] = []
      var i = 0
      while i < n { puntos.append([cs[i].latitude, cs[i].longitude]); i += paso }
      if let ult = cs.last { puntos.append([ult.latitude, ult.longitude]) }
      let res: [String: Any] = [
        "metros": r.distance,
        "segundos": r.expectedTravelTime,
        "puntos": puntos,
      ]
      DispatchQueue.main.async { result(res) }
    }
  }

  // MARK: Dirección de un punto (para "¿Cómo llegar aquí?")

  private func direccion(_ a: [String: Any], _ result: @escaping FlutterResult) {
    guard let c = coord(a, "lat", "lng") else { result(nil); return }
    CLGeocoder().reverseGeocodeLocation(
      CLLocation(latitude: c.latitude, longitude: c.longitude),
      preferredLocale: Locale(identifier: "es_CL")
    ) { marcas, _ in
      var texto: String? = nil
      if let p = marcas?.first {
        var calle = p.thoroughfare ?? p.name ?? ""
        if let n = p.subThoroughfare, !calle.isEmpty { calle += " \(n)" }
        let partes = [calle, p.locality ?? p.subLocality ?? ""].filter { !$0.isEmpty }
        texto = partes.isEmpty ? nil : partes.joined(separator: ", ")
      }
      DispatchQueue.main.async { result(texto) }
    }
  }

  // MARK: Foto fija del mapa (mapas chicos en chats y comunidad)

  private func foto(_ a: [String: Any], _ result: @escaping FlutterResult) {
    guard let c = coord(a, "lat", "lng") else { result(nil); return }
    let w = (a["ancho"] as? NSNumber)?.doubleValue ?? 300
    let h = (a["alto"] as? NSNumber)?.doubleValue ?? 140
    let zoom = (a["zoom"] as? NSNumber)?.doubleValue ?? 15
    let lonDelta = 360.0 / pow(2.0, zoom) * (w / 256.0)
    let latDelta = lonDelta * (h / w) * cos(c.latitude * .pi / 180)
    let opt = MKMapSnapshotter.Options()
    opt.region = MKCoordinateRegion(
      center: c, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    opt.size = CGSize(width: w, height: h)
    opt.scale = UIScreen.main.scale
    if let o = a["oscuro"] as? Bool {
      opt.traitCollection = UITraitCollection(userInterfaceStyle: o ? .dark : .light)
    }
    switch lugares {
    case "ninguno": opt.pointOfInterestFilter = .excludingAll
    case "utiles":
      opt.pointOfInterestFilter = MKPointOfInterestFilter(including: [
        .publicTransport, .parking, .gasStation, .evCharger, .hospital,
        .pharmacy, .police, .atm, .bank, .postOffice, .airport,
      ])
    default: break
    }
    MKMapSnapshotter(options: opt).start { snap, _ in
      let datos = snap?.image.pngData()
      DispatchQueue.main.async {
        result(datos.map { FlutterStandardTypedData(bytes: $0) })
      }
    }
  }

  // MARK: Look Around

  private func lookAround(_ a: [String: Any], _ result: @escaping FlutterResult) {
    guard let c = coord(a, "lat", "lng") else { result(false); return }
    if #available(iOS 16.0, *) {
      MKLookAroundSceneRequest(coordinate: c).getSceneWithCompletionHandler { scene, _ in
        DispatchQueue.main.async {
          guard let scene = scene, let top = self.controladorArriba() else {
            result(false); return
          }
          let vc = MKLookAroundViewController(scene: scene)
          vc.modalPresentationStyle = .pageSheet
          top.present(vc, animated: true)
          result(true)
        }
      }
    } else {
      result(false)
    }
  }

  private func controladorArriba() -> UIViewController? {
    let ventanas = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    var vc = (ventanas.first { $0.isKeyWindow } ?? ventanas.first)?.rootViewController
    while let p = vc?.presentedViewController { vc = p }
    return vc
  }

  // MARK: Estilo (modo claro/oscuro y lugares de Apple)

  private func aplicarEstilo() {
    let ventanas = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    for v in ventanas {
      // La ventana completa toma el modo de OkVenta: el mapa (y la vista
      // de calle, teclado y hojas del sistema) lo heredan siempre, sin
      // depender de encontrar el mapa ni de cuándo se monta. La interfaz
      // de Flutter no cambia: su tema lo decide la app.
      if let o = oscuro {
        v.overrideUserInterfaceStyle = o ? .dark : .light
      } else {
        v.overrideUserInterfaceStyle = .unspecified
      }
      aplicar(en: v)
    }
  }

  private func aplicar(en vista: UIView) {
    if let mapa = vista as? MKMapView {
      if let o = oscuro {
        mapa.overrideUserInterfaceStyle = o ? .dark : .light
      } else {
        mapa.overrideUserInterfaceStyle = .unspecified
      }
      switch lugares {
      case "ninguno":
        mapa.pointOfInterestFilter = .excludingAll
      case "utiles":
        mapa.pointOfInterestFilter = MKPointOfInterestFilter(including: [
          .publicTransport, .parking, .gasStation, .evCharger, .hospital,
          .pharmacy, .police, .atm, .bank, .postOffice, .airport,
        ])
      default:
        mapa.pointOfInterestFilter = .includingAll
      }
      return
    }
    for s in vista.subviews { aplicar(en: s) }
  }
}
