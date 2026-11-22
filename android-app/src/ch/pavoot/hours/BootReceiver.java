package ch.pavoot.hours;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** After a reboot or an app update: re-arm the refresh and bring the notification/widget up to date. */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        String a = i.getAction();
        if (!Intent.ACTION_BOOT_COMPLETED.equals(a) && !Intent.ACTION_MY_PACKAGE_REPLACED.equals(a)) return;
        if (Core.key(c) == null) return;
        c.sendBroadcast(new Intent(c, ActionReceiver.class).setAction("ch.pavoot.hours.refresh"));
    }
}
