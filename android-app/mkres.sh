set -e
cd /work/repo/android-app
mkdir -p res/drawable res/xml
pill(){ printf '<?xml version="1.0" encoding="utf-8"?>\n<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="%s"/><corners android:radius="17dp"/></shape>\n' "$2" > res/drawable/$1.xml; }
pill pill_teal '#3824bdbb'; pill pill_nw '#38f4b678'; pill pill_stop '#38e5484d'
printf '<?xml version="1.0" encoding="utf-8"?>\n<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="#f2061418"/><corners android:radius="22dp"/></shape>\n' > res/drawable/wbg.xml
cat > res/drawable/ic_stat.xml <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
  <path android:fillColor="#FFFFFFFF" android:pathData="M9,1h6v2h-6z M19.03,7.39l1.42,-1.42c-0.43,-0.51 -0.9,-0.99 -1.41,-1.41l-1.42,1.42C16.07,4.74 14.12,4 12,4c-4.97,0 -9,4.03 -9,9s4.02,9 9,9 9,-4.03 9,-9c0,-2.12 -0.74,-4.07 -1.97,-5.61z M12,20c-3.87,0 -7,-3.13 -7,-7s3.13,-7 7,-7 7,3.13 7,7 -3.13,7 -7,7z M11,8h2v6h-2z"/>
</vector>
EOF
cat > res/xml/widget_info.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android" android:minWidth="250dp" android:minHeight="110dp" android:targetCellWidth="4" android:targetCellHeight="2" android:minResizeWidth="180dp" android:minResizeHeight="100dp" android:resizeMode="horizontal|vertical" android:updatePeriodMillis="1800000" android:initialLayout="@layout/widget" android:previewLayout="@layout/widget" android:description="@string/wdesc" android:widgetCategory="home_screen|keyguard" />
EOF
mkdir -p res/values
printf '<?xml version="1.0" encoding="utf-8"?>\n<resources><string name="wdesc">See what is running, stop it or switch topic</string></resources>\n' > res/values/strings.xml
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do mkdir -p res/mipmap-$d; cp /work/old/res/mipmap-$d-v4/ic_launcher.png res/mipmap-$d/; done
echo RES_OK
