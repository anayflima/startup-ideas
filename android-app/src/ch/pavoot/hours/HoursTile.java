package ch.pavoot.hours;

import android.content.Intent;
import android.os.Build;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;
import org.json.JSONObject;

/** Quick Settings tile: one tap starts the last topic or stops the running timer (works from the lock screen). */
public class HoursTile extends TileService {
    @Override
    public void onStartListening() { show(); }

    void show() {
        Tile t = getQsTile();
        if (t == null) return;
        JSONObject s = Core.snap(this);
        JSONObject r = s == null ? null : s.optJSONObject("running");
        t.setState(Core.key(this) == null ? Tile.STATE_UNAVAILABLE : r != null ? Tile.STATE_ACTIVE : Tile.STATE_INACTIVE);
        t.setLabel("Pavoot timer");
        if (Build.VERSION.SDK_INT >= 29) t.setSubtitle(r != null ? Ui.label(r.optString("n")) : "Stopped");
        t.updateTile();
    }

    @Override
    public void onClick() {
        if (Core.key(this) == null) return;
        JSONObject s = Core.snap(this);
        JSONObject r = s == null ? null : s.optJSONObject("running");
        Intent i = new Intent(this, ActionReceiver.class);
        if (r != null) {
            i.setAction("ch.pavoot.hours.stop");
        } else {
            JSONObject l = s == null ? null : s.optJSONObject("last");
            i.setAction("ch.pavoot.hours.start").putExtra("topic", l == null ? "" : l.optString("n")).putExtra("nw", l != null && l.optBoolean("p"));
        }
        sendBroadcast(i);
        Tile t = getQsTile();
        if (t != null) { t.setState(r != null ? Tile.STATE_INACTIVE : Tile.STATE_ACTIVE); t.updateTile(); }
    }
}
