package ch.pavoot.hours;

import android.app.RemoteInput;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;
import org.json.JSONObject;

/** Stop / start / switch topic from the notification, widget or tile, and the periodic refresh. Not exported. */
public class ActionReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c0, Intent i) {
        final Context c = c0.getApplicationContext();
        final String a = i.getAction();
        if (a == null) return;
        final PendingResult pr = goAsync();
        new Thread(() -> {
            boolean user = !a.endsWith(".refresh");
            try {
                if (a.endsWith(".stop")) {
                    Core.call(c, "hr_stop", null);
                } else if (a.endsWith(".start")) {
                    String topic = i.getStringExtra("topic");
                    Bundle ri = RemoteInput.getResultsFromIntent(i);
                    if (ri != null && ri.getCharSequence("topic") != null) topic = ri.getCharSequence("topic").toString().trim();
                    JSONObject args = new JSONObject().put("p_note", topic == null ? "" : topic).put("p_nw", i.getBooleanExtra("nw", false));
                    Core.call(c, "hr_start", args);
                } else if (Core.key(c) != null) {
                    Core.call(c, "hr_state", null);
                }
                if (user) Ui.update(c, Core.snap(c));
                MainActivity.refreshWeb();
            } catch (Exception e) {
                if (user) {
                    Ui.update(c, Core.snap(c));
                    String m = "Pavoot Hours: " + e.getMessage();
                    new Handler(Looper.getMainLooper()).post(() -> Toast.makeText(c, m, Toast.LENGTH_LONG).show());
                }
            } finally {
                pr.finish();
            }
        }).start();
    }
}
