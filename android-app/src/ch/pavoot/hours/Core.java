package ch.pavoot.hours;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.SystemClock;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Sign-in key + last known state, the Neon Data API calls, and the snapshot the notification/widget/tile show. */
final class Core {
    static final String REST = "https://ep-sweet-heart-b9jc9c7i.apirest.c-7.eu-central-1.aws.neon.tech/neondb/rest/v1";
    static final String AUTH = "https://ep-sweet-heart-b9jc9c7i.neonauth.c-7.eu-central-1.aws.neon.tech/neondb/auth/token/anonymous";
    static final String APP = "https://anayflima.github.io/startup-ideas/hours/";
    static final String[] WORK_DEF = {"Meetings"};
    static final String[] NW_DEF = {"Meal", "Calls", "Commuting", "Apartment search", "Personal"};

    static SharedPreferences prefs(Context c) { return c.getSharedPreferences("hours", Context.MODE_PRIVATE); }
    static String key(Context c) { return prefs(c).getString("key", null); }
    static JSONObject snap(Context c) {
        try { String s = prefs(c).getString("snap", null); return s == null ? null : new JSONObject(s); } catch (Exception e) { return null; }
    }

    static final class Resp { int code; String body; }

    static Resp http(String u, String auth, String body) throws IOException {
        HttpURLConnection h = (HttpURLConnection) new URL(u).openConnection();
        h.setConnectTimeout(15000);
        h.setReadTimeout(20000);
        h.setUseCaches(false);
        if (auth != null) h.setRequestProperty("Authorization", "Bearer " + auth);
        if (body != null) {
            h.setRequestMethod("POST");
            h.setDoOutput(true);
            h.setRequestProperty("Content-Type", "application/json");
            try (OutputStream o = h.getOutputStream()) { o.write(body.getBytes(StandardCharsets.UTF_8)); }
        }
        Resp r = new Resp();
        r.code = h.getResponseCode();
        InputStream in = r.code >= 400 ? h.getErrorStream() : h.getInputStream();
        r.body = in == null ? "" : read(in);
        h.disconnect();
        return r;
    }

    static String read(InputStream in) throws IOException {
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        byte[] x = new byte[8192];
        int n;
        while ((n = in.read(x)) > 0) b.write(x, 0, n);
        in.close();
        return new String(b.toByteArray(), StandardCharsets.UTF_8);
    }

    static JSONObject rpc(Context c, String fn, JSONObject args) throws Exception {
        String k = key(c);
        if (k == null) throw new Exception("Open Pavoot Hours and sign in first");
        if (args == null) args = new JSONObject();
        args.put("p_key", k);
        for (int i = 0; i < 2; i++) {
            String t = new JSONObject(http(AUTH, null, null).body).getString("token");
            Resp r = http(REST + "/rpc/" + fn, t, args.toString());
            if (r.code >= 200 && r.code < 300) return new JSONObject(r.body);
            if (i == 0 && r.code == 401) continue;
            String m = "HTTP " + r.code;
            try { m = new JSONObject(r.body).optString("message", m); } catch (Exception e) { }
            throw new Exception(m);
        }
        throw new Exception("Could not reach the server");
    }

    /** Calls an RPC (they all return the full state) and updates notification, widgets and tile. */
    static void call(Context c, String fn, JSONObject args) throws Exception { apply(c, rpc(c, fn, args)); }

    static long time(String s) {
        if (s == null) return 0;
        s = s.trim().replace(' ', 'T');
        if (s.isEmpty() || s.equals("null")) return 0;
        if (s.matches(".*[+-]\\d\\d$")) s += ":00";
        try { return OffsetDateTime.parse(s).toInstant().toEpochMilli(); } catch (Exception e) { return 0; }
    }

    static final class E { String n; long s, e; boolean p; }

    static long sod(long t) {
        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(t);
        c.set(Calendar.HOUR_OF_DAY, 0); c.set(Calendar.MINUTE, 0); c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0);
        return c.getTimeInMillis();
    }

    static JSONObject build(JSONObject d) throws Exception {
        String me = String.valueOf(d.opt("me"));
        JSONArray es = d.optJSONArray("entries");
        if (es == null) es = new JSONArray();
        List<E> mine = new ArrayList<>();
        for (int i = 0; i < es.length(); i++) {
            JSONObject x = es.getJSONObject(i);
            if (!me.equals(String.valueOf(x.opt("u")))) continue;
            E e = new E();
            e.s = x.isNull("s") ? 0 : time(x.optString("s"));
            if (e.s == 0) continue;
            e.e = x.isNull("e") ? 0 : time(x.optString("e"));
            String n = x.isNull("n") ? "" : x.optString("n").trim();
            if (n.equalsIgnoreCase("lunch")) n = "Meal";
            e.n = n;
            e.p = x.optBoolean("p");
            mine.add(e);
        }
        Collections.sort(mine, (a, b) -> Long.compare(a.s, b.s));
        E r = null, last = null;
        for (E e : mine) { if (e.e == 0) r = e; else last = e; }
        Set<String> seen = new HashSet<>();
        if (r != null) seen.add((r.p ? "p:" : "w:") + r.n.toLowerCase());
        List<String> work = new ArrayList<>(), nw = new ArrayList<>();
        for (int i = mine.size() - 1; i >= 0; i--) {
            E x = mine.get(i);
            if (x.e == 0 || x.n.isEmpty()) continue;
            if (!seen.add((x.p ? "p:" : "w:") + x.n.toLowerCase())) continue;
            (x.p ? nw : work).add(x.n);
        }
        for (String n : WORK_DEF) if (seen.add("w:" + n.toLowerCase())) work.add(n);
        for (String n : NW_DEF) if (seen.add("p:" + n.toLowerCase())) nw.add(n);
        // On a break: back-to-work topics first. Working: mix work topics with break options.
        boolean[] pat = (r != null && r.p) ? new boolean[]{false, false, true, false, true, false} : new boolean[]{false, true, false, true, false, true};
        JSONArray sugg = new JSONArray();
        int wi = 0, ni = 0;
        for (boolean want : pat) {
            if (sugg.length() >= 4) break;
            if (want) { if (ni < nw.size()) sugg.put(new JSONObject().put("n", nw.get(ni++)).put("p", true)); }
            else if (wi < work.size()) sugg.put(new JSONObject().put("n", work.get(wi++)).put("p", false));
        }
        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0);
        long sod = cal.getTimeInMillis(), now = System.currentTimeMillis(), today = 0;
        for (E x : mine) {
            if (x.p || x.e == 0) continue;
            long a = Math.max(x.s, sod), b = Math.min(x.e, now);
            if (b > a) today += b - a;
        }
        JSONObject o = new JSONObject();
        if (r != null) o.put("running", new JSONObject().put("n", r.n).put("s", r.s).put("p", r.p));
        o.put("sugg", sugg);
        if (last != null) o.put("last", new JSONObject().put("n", last.n).put("p", last.p));
        o.put("today", today);
        return o;
    }

    static synchronized void apply(Context c, JSONObject d) {
        try {
            JSONObject s = build(d);
            String js = s.toString(), old = prefs(c).getString("snap", null);
            prefs(c).edit().putString("snap", js).apply();
            if (!js.equals(old)) Ui.update(c, s);
        } catch (Exception e) { }
        schedule(c);
    }

    /** Re-checks the server every ~15 min so a timer started or stopped on another device shows up. */
    static void schedule(Context c) {
        AlarmManager am = c.getSystemService(AlarmManager.class);
        PendingIntent pi = Ui.act(c, "refresh", null, false, 90);
        if (key(c) == null) { am.cancel(pi); return; }
        am.setInexactRepeating(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime() + AlarmManager.INTERVAL_FIFTEEN_MINUTES,
                AlarmManager.INTERVAL_FIFTEEN_MINUTES, pi);
    }
}
