package ch.pavoot.hours;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;

/** Home-screen widget: what is running (live timer), Stop / Start, and topic chips to switch. */
public class HoursWidget extends AppWidgetProvider {
    @Override
    public void onUpdate(Context c, AppWidgetManager m, int[] ids) {
        m.updateAppWidget(ids, Ui.views(c, Core.snap(c)));
        if (Core.key(c) != null) c.sendBroadcast(new Intent(c, ActionReceiver.class).setAction("ch.pavoot.hours.refresh"));
    }
}
