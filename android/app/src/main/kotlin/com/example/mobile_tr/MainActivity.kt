package com.example.mobile_tr

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.provider.Settings

class MainActivity : FlutterFragmentActivity() {
    private val canal = "stylear_transacciones_v1"
    private var puente: MethodChannel? = null
    private var pendiente: Map<String, Long>? = null
    private fun referencia(intent: Intent?): Map<String, Long>? {
        val nid = intent?.getLongExtra("stylear_notificacion_id", 0) ?: 0
        val eid = intent?.getLongExtra("stylear_empresa_id", 0) ?: 0
        return if (nid > 0 && eid > 0) mapOf("notificacion_id" to nid, "empresa_id" to eid) else null
    }
    private fun crearCanal() {
        if (Build.VERSION.SDK_INT >= 26) {
            val gestor = getSystemService(NotificationManager::class.java)
            if (gestor.getNotificationChannel(canal) == null) {
                gestor.createNotificationChannel(NotificationChannel(canal, "Actualizaciones de StyleAR", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Compras, reservas, entregas y atención de tu cuenta"
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                })
            }
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        crearCanal()
        pendiente = referencia(intent)
        puente = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stylear/notificaciones")
        puente!!.setMethodCallHandler { call, result ->
            val gestor = getSystemService(NotificationManager::class.java)
            when (call.method) {
                "inicializar" -> { crearCanal(); result.success(null) }
                "inicio" -> { result.success(pendiente); pendiente = null }
                "cancelar" -> { gestor.cancelAll(); result.success(null) }
                "estado" -> result.success(mapOf("permitidas" to (Build.VERSION.SDK_INT < 24 || gestor.areNotificationsEnabled()), "importancia" to (if (Build.VERSION.SDK_INT >= 26) gestor.getNotificationChannel(canal)?.importance else 4)))
                "ajustes" -> {
                    startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                    result.success(null)
                }
                "mostrar" -> {
                    val nid = call.argument<Number>("notificacion_id")?.toLong() ?: 0
                    val eid = call.argument<Number>("empresa_id")?.toLong() ?: 0
                    if (nid <= 0 || eid <= 0) { result.error("REFERENCIA", "Referencia inválida", null); return@setMethodCallHandler }
                    val tag = "stylear_${eid}_${nid}"
                    val abrir = Intent(this, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        .putExtra("stylear_notificacion_id", nid).putExtra("stylear_empresa_id", eid)
                    val accion = PendingIntent.getActivity(this, tag.hashCode(), abrir, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, canal) else Notification.Builder(this)
                    val aviso = builder.setSmallIcon(R.drawable.ic_stylear_notification).setContentTitle("StyleAR")
                        .setContentText("Tienes una actualización. Abre tu bandeja para consultarla.")
                        .setContentIntent(accion).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE)
                        .setPriority(Notification.PRIORITY_HIGH).setCategory(Notification.CATEGORY_STATUS).build()
                    try { gestor.notify(tag, 0, aviso); result.success(null) }
                    catch (_: SecurityException) { result.error("PERMISO", "Permiso de avisos no disponible", null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendiente = referencia(intent)
        pendiente?.let { puente?.invokeMethod("abrir", it) }
    }
}
