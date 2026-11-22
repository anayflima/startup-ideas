package ch.pavoot.hours;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.RemoteInput;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.service.quicksettings.TileService;
import android.view.View;
import android.widget.RemoteViews;
import org.json.JSONArray;
import org.json.JSONObject;

/** The ongoing "timer running" notification (status bar chip / lock screen), the home-screen widget and the tile. */
final class Ui {
    static final int TEAL = 0xff24bdbb, NW = 0xfff4b678, STOP = 0xffe5484d;

    static PendingIntent act(Context c, String a, String topic, boolean nw, int rc) {
        Intent i = new Intent(c, ActionReceiver.class).setAction("ch.pavoot.hours." + a);
        if (topic != null) i.putExtra("topic", topic);
        i.putExtra("nw", nw);
        return PendingIntent.getBroadcast(c, rc, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    static PendingIntent openApp(Context c) {
        Intent i = new Intent(c, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        return PendingIntent.getActivity(c, 0, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    static String label(String n) { return n == null || n.isEmpty() ? "No description" : n; }

    static String hm(long ms) { long m = Math.max(0, ms) / 60000; return (m / 60) + "h " + String.format("%02d", m % 60) + "m"; }

    static void update(Context c, JSONObject s) {
        try { notif(c, s); } catch (Exception e) { }
        try { widgets(c, s); } catch (Exception e) { }
        try { TileService.requestListeningState(c, new ComponentName(c, HoursTile.class)); } catch (Exception e) { }
    }

    static void notif(Context c, JSONObject s) throws Exception {
        NotificationManager nm = c.getSystemService(NotificationManager.class);
        JSONObject r = s == null ? null : s.optJSONObject("running");
        if (r == null) { nm.cancel(1); return; }
        NotificationChannel ch = new NotificationChannel("timer", "Running timer", NotificationManager.IMPORTANCE_DEFAULT);
        ch.setDescription("Shows the running timer with Stop and switch buttons");
        ch.setSound(null, null);
        ch.enableVibration(false);
        ch.setShowBadge(false);
        ch.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
        nm.createNotificationChannel(ch);
        boolean p = r.optBoolean("p");
        String n = r.optString("n");
        Notification.Builder b = new Notification.Builder(c, "timer")
                .setSmallIcon(R.drawable.ic_stat)
                .setContentTitle(label(n))
                .setContentText(p ? "☕ Not work" : "💼 Working")
                .setWhen(r.optLong("s"))
                .setShowWhen(true)
                .setUsesChronometer(true)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setCategory(Notification.CATEGORY_STOPWATCH)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setColor(p ? NW : TEAL)
                .setContentIntent(openApp(c));
        Icon ic = Icon.createWithResource(c, R.drawable.ic_stat);
        b.addAction(new Notification.Action.Builder(ic, "■ Stop", act(c, "stop", null, false, 1)).build());
        RemoteInput ri = new RemoteInput.Builder("topic").setLabel("New topic").build();
        Intent ti = new Intent(c, ActionReceiver.class).setAction("ch.pavoot.hours.start").putExtra("nw", false);
        PendingIntent tp = PendingIntent.getBroadcast(c, 2, ti,
                PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 31 ? PendingIntent.FLAG_MUTABLE : 0));
        b.addAction(new Notification.Action.Builder(ic, "✏️ New topic", tp).addRemoteInput(ri).build());
        JSONArray sg = s.optJSONArray("sugg");
        if (sg != null && sg.length() > 0) {
            JSONObject x = sg.getJSONObject(0);
            boolean xp = x.optBoolean("p");
            b.addAction(new Notification.Action.Builder(ic, (xp ? "☕ " : "▶ ") + x.optString("n"),
                    act(c, "start", x.optString("n"), xp, 3)).build());
        }
        // Android 16 Live Update: promoted ongoing notification = status bar chip with the running time.
        Bundle ex = new Bundle();
        ex.putBoolean("android.requestPromotedOngoing", true);
        b.addExtras(ex);
        nm.notify(1, b.build());
    }

    static void widgets(Context c, JSONObject s) {
        AppWidgetManager m = AppWidgetManager.getInstance(c);
        int[] ids = m.getAppWidgetIds(new ComponentName(c, HoursWidget.class));
        if (ids == null || ids.length == 0) return;
        m.updateAppWidget(ids, views(c, s));
    }

    static RemoteViews views(Context c, JSONObject s) {
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.widget);
        boolean signed = Core.key(c) != null;
        JSONObject r = s == null ? null : s.optJSONObject("running");
        v.setOnClickPendingIntent(R.id.w_root, openApp(c));
        if (r != null) {
            boolean p = r.optBoolean("p");
            v.setTextViewText(R.id.w_head, p ? "☕ NOT WORK" : "💼 WORKING");
            v.setTextColor(R.id.w_head, p ? NW : TEAL);
            v.setTextViewText(R.id.w_topic, label(r.optString("n")));
            long st = r.optLong("s");
            v.setChronometer(R.id.w_chrono, SystemClock.elapsedRealtime() - (System.currentTimeMillis() - st), null, true);
            v.setViewVisibility(R.id.w_chrono, View.VISIBLE);
            v.setViewVisibility(R.id.w_today, View.GONE);
            v.setTextViewText(R.id.w_main, "■  Stop");
            v.setTextColor(R.id.w_main, STOP);
            v.setInt(R.id.w_main, "setBackgroundResource", R.drawable.pill_stop);
            v.setOnClickPendingIntent(R.id.w_main, act(c, "stop", null, false, 10));
        } else {
            v.setTextViewText(R.id.w_head, "⏱ PAVOOT HOURS");
            v.setTextColor(R.id.w_head, 0x99ffffff);
            v.setTextViewText(R.id.w_topic, signed ? "Not tracking" : "Open the app to sign in");
            v.setChronometer(R.id.w_chrono, SystemClock.elapsedRealtime(), null, false);
            v.setViewVisibility(R.id.w_chrono, View.GONE);
            v.setViewVisibility(R.id.w_today, View.VISIBLE);
            v.setTextViewText(R.id.w_today, "Today " + hm(s == null ? 0 : s.optLong("today")));
            JSONObject l = s == null ? null : s.optJSONObject("last");
            String ln = l == null ? "" : l.optString("n");
            boolean lp = l != null && l.optBoolean("p");
            v.setTextViewText(R.id.w_main, "▶  " + (ln.isEmpty() ? "Start" : ln));
            v.setTextColor(R.id.w_main, lp ? NW : TEAL);
            v.setInt(R.id.w_main, "setBackgroundResource", lp ? R.drawable.pill_nw : R.drawable.pill_teal);
            v.setOnClickPendingIntent(R.id.w_main, signed ? act(c, "start", ln, lp, 10) : openApp(c));
        }
        v.setTextViewText(R.id.w_sl, r == null ? "START" : "SWITCH TO");
        int[] ids = {R.id.w_s1, R.id.w_s2, R.id.w_s3};
        JSONArray sg = s == null ? null : s.optJSONArray("sugg");
        for (int i = 0; i < 3; i++) {
            JSONObject x = (!signed || sg == null || i >= sg.length()) ? null : sg.optJSONObject(i);
            if (x == null) { v.setViewVisibility(ids[i], View.INVISIBLE); continue; }
            boolean p = x.optBoolean("p");
            v.setViewVisibility(ids[i], View.VISIBLE);
            v.setTextViewText(ids[i], (p ? "☕ " : "▶ ") + x.optString("n"));
            v.setTextColor(ids[i], p ? NW : TEAL);
            v.setInt(ids[i], "setBackgroundResource", p ? R.drawable.pill_nw : R.drawable.pill_teal);
            v.setOnClickPendingIntent(ids[i], act(c, "start", x.optString("n"), p, 11 + i));
        }
        return v;
    }
}
