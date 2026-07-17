# FAQ OkVenta — Base de conocimiento del agente de soporte

> Generado a partir del código real del repo (máquina de estados en
> `database/ordenes.py`, pagos en `services/mp_service.py` y `main.py`,
> servicios en `database/servicios.py`, entregas en `routers/okdelivery.py`).
> Las políticas no implementadas o no documentadas están marcadas
> `[FALTA CONFIRMAR]` — el agente NO debe responderlas como definitivas.

---

## Pagos y retención de fondos (escrow)

### ¿Cómo funciona el pago cuando compro algo?
Pagas a través de Mercado Pago. OkVenta **retiene el pago** (no le llega
directo al vendedor): la orden queda en estado `pago_confirmado` y el dinero
solo se libera al vendedor cuando confirmas que recibiste el producto (o
cuando pasa el plazo de confirmación automática). Esto protege a ambas partes.

### ¿Cuándo se libera el pago al vendedor?
Cuando la orden llega al estado `entregado`. Eso ocurre por cualquiera de
estas vías:
1. El comprador confirma la recepción (con foto, escaneando el QR de la
   etiqueta, o con el botón de confirmación).
2. **Confirmación automática**: si el vendedor reportó la entrega con foto y
   el comprador no responde en **48 horas**, la orden se confirma sola (con
   un recordatorio a las 24 horas). Una orden en disputa NUNCA se
   auto-confirma.
En entregas OkDelivery, el comprador tiene **1 hora** desde que el repartidor
entrega para confirmar o reclamar; si no responde, se cierra y se liberan los
fondos.

### ¿Cómo le llega la plata al vendedor?
El pago se marca como liberado en el sistema y OkVenta coordina la
transferencia al vendedor (payout manual mientras no exista payout automático
de Mercado Pago). El mensaje que recibe el vendedor es: "Coordina con OkVenta
la transferencia a tu cuenta".
[FALTA CONFIRMAR] Plazo exacto en días para que la transferencia llegue a la
cuenta del vendedor.

### ¿Cuánto cobra OkVenta de comisión?
La comisión se calcula sobre el monto de la venta según el porcentaje
configurado (variable `MP_COMISION_PCT`, por defecto **5%**). El vendedor
recibe el monto menos esa comisión.

### ¿Qué pasa si mi pago falla o queda pendiente?
La orden queda en `pendiente_pago` y no se notifica al vendedor ni avanza el
flujo. Puedes reintentar el pago desde la misma publicación. Si Mercado Pago
rechaza el pago, no se genera ningún cobro.
[FALTA CONFIRMAR] Tiempo tras el cual una orden `pendiente_pago` expira o se
limpia automáticamente (hoy no hay expiración implementada).

---

## Estados de una orden y tiempos

### ¿Cuáles son los estados de mi orden?
`pendiente_pago` → `pago_confirmado` → `en_camino` → `entrega_reportada`
→ `entregado`. Estados alternativos: `en_disputa` (reportaste un problema),
`reembolsado` (se devolvió el pago), `cancelado`.

### ¿Dónde está mi pedido? / ¿Qué significa cada estado?
- **Pago confirmado**: tu pago fue aprobado; el vendedor debe elegir cómo
  entregarte (él mismo, OkVenta Delivery o Blue Express).
- **En camino**: el vendedor ya despachó. Si eligió "Lo entrego yo", puedes
  ver su ubicación en tiempo real en el mapa desde Mis Compras.
- **Confirma recepción** (`entrega_reportada`): el vendedor reportó con foto
  que entregó. Tienes 48 horas para confirmar o reportar un problema.
- **Entregado**: la orden cerró y el pago se libera al vendedor.

### ¿Cuánto demora la entrega?
Depende del método que elija el vendedor: entrega personal (mismo día es lo
promovido en la app: "Entrega tu venta hoy"), OkVenta Delivery (red de
repartidores locales) o Blue Express (despacho a todo Chile, según sus plazos).
[FALTA CONFIRMAR] No hay SLA de tiempo máximo de despacho para el vendedor —
hoy no existe un plazo tras el cual una orden `pago_confirmado` sin despachar
se cancele automáticamente.

---

## Los 3 flujos de OkVenta

### Compra de producto
Ves una publicación → pagas por Mercado Pago → el pago queda retenido → el
vendedor entrega (con tracking en vivo si entrega él mismo) → confirmas la
recepción → se libera el pago. Todo el proceso queda registrado con evidencia
fotográfica de entrega y recepción.

### "Busco servicio" (seeking)
Publicas lo que necesitas (ej. "busco gásfiter en Ñuñoa") con comunas y radio
de cobertura. Los oferentes te contactan. El contacto queda registrado en la
app. Si el servicio se contrata con pago por OkVenta, sigue la misma máquina
de estados y retención de fondos que un producto (`tipo='servicio'`).

### "Ofrezco servicio" (offering)
Publicas tu servicio con categoría, comunas de cobertura y opcionalmente un
certificado (ej. título o credencial, con verificación). Los interesados te
contactan y pueden valorarte con estrellas después.
[FALTA CONFIRMAR] Criterio exacto de "certificado verificado" (hoy el flag
existe en la base de datos pero el proceso de verificación no está descrito).

---

## Cancelaciones, problemas y devoluciones

### ¿Puedo cancelar una compra?
[FALTA CONFIRMAR] **Hoy no existe cancelación self-service en la app**: el
estado `cancelado` está definido pero ningún flujo lo activa. Una cancelación
debe gestionarse contactando a soporte (ticket de ayuda), y la devolución del
dinero se ejecuta como reembolso vía Mercado Pago por el equipo OkVenta.
El agente de soporte podrá *solicitar* una cancelación, que requiere
confirmación explícita del usuario y validación del equipo.

### Recibí algo dañado / no es lo que compré / nunca llegó
Desde Mis Compras puedes **reportar un problema** (botón "Tuve un problema")
con motivo, descripción y foto. La orden pasa a `en_disputa`: se congela la
liberación del pago (incluida la auto-confirmación de 48h) y el equipo
OkVenta media entre las partes. Ambas partes reciben notificación.

### ¿Cómo funciona el reembolso?
Si la disputa se resuelve a favor del comprador, OkVenta ejecuta el reembolso
a través de Mercado Pago (el dinero vuelve al medio de pago original) y la
orden queda en estado `reembolsado`.
[FALTA CONFIRMAR] Plazos de resolución de disputas y criterios de decisión —
hoy la mediación es manual y sin SLA definido.

### ¿Qué evidencia queda del proceso?
Cada orden guarda una bitácora auditable: hora del pago, método de entrega
elegido, hora y ubicación GPS de la entrega, fotos de entrega y recepción
(nunca se sobreescriben), y cualquier disputa. Esto es lo que usa OkVenta
para mediar si hay desacuerdo.

---

## Publicar y vender

### ¿Cómo publico un producto?
Desde la app: foto (la IA ayuda a analizar el producto), título, descripción
y precio. La publicación queda visible para compradores cercanos (búsqueda
por ubicación).

### ¿Cómo entrego lo que vendí?
Cuando te compran, eliges entre: **"Lo entrego yo"** (imprimes una etiqueta
con doble QR, compartes tu ubicación en vivo y el comprador confirma
escaneando el QR al recibir), **OkVenta Delivery** (un repartidor retira y
entrega, con evidencia fotográfica en cada paso) o **Blue Express** (courier
tradicional).

### ¿Qué pasa si el comprador nunca confirma la recepción?
Si reportaste la entrega con foto, a las 24 horas se le envía un recordatorio
y a las **48 horas** la venta se confirma automáticamente y se libera tu pago
— salvo que el comprador haya abierto una disputa antes.

---

## Contacto con soporte humano

### ¿Cómo hablo con una persona?
Desde la sección Ayuda de la app se crea un ticket (tipo de problema, número
de referencia opcional y detalle). El equipo OkVenta recibe una notificación
inmediata (integración n8n) y te responde por el mismo canal.
