package ch.pavoot.hours;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Insets;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.window.OnBackInvokedDispatcher;
import org.json.JSONObject;
import java.lang.ref.WeakReference;

public class MainActivity extends Activity {
    static final int BG = 0xff061418;
    static volatile WeakReference<MainActivity> CUR;
    WebView web;

    /** Called by the web app on every state load, and on sign-out. */
    static final class Bridge {
        final Context c;
        Bridge(Context c) { this.c = c; }
        @JavascriptInterface
        public void state(String key, String json) {
            try {
                if (key != null && !key.isEmpty() && !key.equals(Core.key(c))) Core.prefs(c).edit().putString("key", key).apply();
                Core.apply(c, new JSONObject(json));
            } catch (Exception e) { }
        }
        @JavascriptInterface
        public void signout() {
            Core.prefs(c).edit().clear().apply();
            Ui.update(c, null);
            Core.schedule(c);
        }
    }

    static void refreshWeb() {
        WeakReference<MainActivity> w = CUR;
        MainActivity a = w == null ? null : w.get();
        if (a == null) return;
        a.runOnUiThread(() -> { if (a.web != null) a.web.evaluateJavascript("typeof refresh==='function'&&refresh()", null); });
    }

    static boolean inside(Uri u) {
        String sc = u.getScheme() == null ? "" : u.getScheme();
        if (sc.equals("about") || sc.equals("blob") || sc.equals("data")) return true;
        String p = u.getPath() == null ? "" : u.getPath();
        return "anayflima.github.io".equals(u.getHost()) && p.startsWith("/startup-ideas/hours") && !p.endsWith(".apk") && !p.endsWith(".mjs");
    }

    void open(Uri u) {
        try { startActivity(new Intent(Intent.ACTION_VIEW, u).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); } catch (Exception e) { }
    }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        CUR = new WeakReference<>(this);
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(BG);
        web = new WebView(this);
        web.setBackgroundColor(BG);
        root.addView(web, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        if (Build.VERSION.SDK_INT >= 30) {
            getWindow().setDecorFitsSystemWindows(false);
            root.setOnApplyWindowInsetsListener((v, ins) -> {
                Insets i = ins.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.ime() | WindowInsets.Type.displayCutout());
                v.setPadding(i.left, i.top, i.right, i.bottom);
                return WindowInsets.CONSUMED;
            });
        } else {
            getWindow().setStatusBarColor(BG);
            getWindow().setNavigationBarColor(BG);
        }
        setContentView(root);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setUserAgentString(s.getUserAgentString() + " PavootHoursApp/2.0 (Android)");
        web.addJavascriptInterface(new Bridge(getApplicationContext()), "PavootNative");
        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (inside(u)) return false;
                open(u);
                return true;
            }
        });
        web.setDownloadListener((url, ua, cd, mime, len) -> open(Uri.parse(url)));
        if (b != null) web.restoreState(b);
        if (web.getUrl() == null) web.loadUrl(Core.APP);
        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED)
                requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 1);
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, () -> {
                if (web.canGoBack()) web.goBack(); else moveTaskToBack(true);
            });
        }
        Core.schedule(this);
    }

    @Override
    public void onBackPressed() {
        if (web != null && web.canGoBack()) web.goBack(); else moveTaskToBack(true);
    }

    @Override
    protected void onResume() {
        super.onResume();
        CUR = new WeakReference<>(this);
        refreshWeb();
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        if (web != null) web.saveState(out);
    }
}
