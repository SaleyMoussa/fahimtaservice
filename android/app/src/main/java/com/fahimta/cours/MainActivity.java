package com.fahimta.cours;

import android.Manifest;
import android.app.Activity;
import android.app.DownloadManager;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.URLUtil;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ProgressBar;
import android.widget.Toast;

/**
 * Application Fahimta Cours : affiche le site Fahimta dans une fenêtre d'application
 * et ajoute ce qu'un simple navigateur intégré ne sait pas faire seul
 * (téléchargements, liens WhatsApp/YouTube, impression des attestations, hors connexion).
 */
public class MainActivity extends Activity {

    private static final String SITE = BuildConfig.SITE_URL;
    private static final String OFFLINE = "file:///android_asset/hors-ligne.html";
    private static final int REQ_STORAGE = 7;

    private WebView web;
    private ProgressBar bar;
    private String lastUrl = SITE;
    private String[] pendingDownload; // url, userAgent, contentDisposition, mimeType

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.parseColor("#F6F8FB"));
        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        bar.setMax(100);
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(4), Gravity.TOP);
        root.addView(bar, lp);
        setContentView(root);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);          // garde la connexion à l'Espace apprenant
        s.setDatabaseEnabled(true);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        s.setBuiltInZoomControls(true);
        s.setDisplayZoomControls(false);
        s.setMediaPlaybackRequiresUserGesture(true);
        s.setAllowFileAccess(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setUserAgentString(s.getUserAgentString() + " FahimtaApp/" + BuildConfig.VERSION_NAME);
        CookieManager.getInstance().setAcceptCookie(true);

        web.addJavascriptInterface(new Pont(), "FahimtaAndroid");
        web.setWebChromeClient(new WebChromeClient() {   // active aussi alert(), confirm(), prompt()
            @Override public void onProgressChanged(WebView v, int p) {
                bar.setProgress(p);
                bar.setVisibility(p < 100 ? View.VISIBLE : View.GONE);
            }
        });
        web.setWebViewClient(new Client());
        web.setDownloadListener((url, ua, cd, mime, len) -> telecharger(url, ua, cd, mime));

        if (state != null) web.restoreState(state);
        else web.loadUrl(SITE);
    }

    @Override protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    @Override public void onBackPressed() {
        if (OFFLINE.equals(web.getUrl()) && web.canGoBack()) { web.goBack(); return; }
        if (web.canGoBack()) web.goBack();
        else super.onBackPressed();
    }

    @Override protected void onPause() { super.onPause(); CookieManager.getInstance().flush(); web.onPause(); }
    @Override protected void onResume() { super.onResume(); web.onResume(); }

    // ---------- Navigation ----------
    private class Client extends WebViewClient {
        @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
            return ouvrirAilleurs(r.getUrl());
        }

        @SuppressWarnings("deprecation")
        @Override public boolean shouldOverrideUrlLoading(WebView v, String url) {
            return ouvrirAilleurs(Uri.parse(url));
        }

        @Override public void onPageStarted(WebView v, String url, Bitmap fav) {
            if (url != null && url.startsWith("http")) lastUrl = url;
        }

        @Override public void onPageFinished(WebView v, String url) {
            // window.print() n'existe pas dans une application : on le relie à l'impression Android
            v.evaluateJavascript("window.print=function(){FahimtaAndroid.imprimer(document.title||'Fahimta')};", null);
        }

        @Override public void onReceivedError(WebView v, WebResourceRequest r, WebResourceError e) {
            if (r.isForMainFrame()) v.loadUrl(OFFLINE);
        }

        @SuppressWarnings("deprecation")
        @Override public void onReceivedError(WebView v, int code, String desc, String url) {
            if (url != null && url.equals(v.getUrl())) v.loadUrl(OFFLINE);
        }
    }

    /** true = le lien est ouvert hors de l'application (WhatsApp, YouTube, téléphone…). */
    private boolean ouvrirAilleurs(Uri u) {
        String scheme = u.getScheme() == null ? "" : u.getScheme();
        String host = u.getHost() == null ? "" : u.getHost();
        if (scheme.equals("file")) return false;
        if (scheme.equals("https") && (host.equals(BuildConfig.SITE_HOST) || host.endsWith(".supabase.co"))) return false;
        try {
            Intent i;
            if (scheme.equals("intent")) i = Intent.parseUri(u.toString(), Intent.URI_INTENT_SCHEME);
            else i = new Intent(Intent.ACTION_VIEW, u);
            i.addCategory(Intent.CATEGORY_BROWSABLE);
            startActivity(i);
        } catch (ActivityNotFoundException | java.net.URISyntaxException e) {
            Toast.makeText(this, "Aucune application ne peut ouvrir ce lien.", Toast.LENGTH_SHORT).show();
        }
        return true;
    }

    // ---------- Téléchargements (fiches, modules, présentations) ----------
    private void telecharger(String url, String ua, String cd, String mime) {
        if (url.startsWith("blob:") || url.startsWith("data:")) {
            Toast.makeText(this, "Ce fichier se télécharge depuis le site dans Chrome.", Toast.LENGTH_LONG).show();
            return;
        }
        if (Build.VERSION.SDK_INT >= 23 && Build.VERSION.SDK_INT <= 28
                && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            pendingDownload = new String[]{url, ua, cd, mime};
            requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQ_STORAGE);
            return;
        }
        try {
            String nom = URLUtil.guessFileName(url, cd, mime);
            if (mime == null || mime.isEmpty() || mime.equals("application/octet-stream")) mime = typeDe(nom);
            DownloadManager.Request req = new DownloadManager.Request(Uri.parse(url));
            req.setMimeType(mime);
            req.addRequestHeader("User-Agent", ua);
            req.setTitle(nom);
            req.setDescription("Fahimta Cours");
            req.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            req.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "Fahimta/" + nom);
            ((DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE)).enqueue(req);
            Toast.makeText(this, "Téléchargement de « " + nom + " » dans Téléchargements/Fahimta", Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            // En dernier recours, on confie le fichier au navigateur
            try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); }
            catch (Exception ignored) { Toast.makeText(this, "Téléchargement impossible.", Toast.LENGTH_LONG).show(); }
        }
    }

    private static String typeDe(String nom) {
        String n = nom.toLowerCase();
        if (n.endsWith(".docx")) return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
        if (n.endsWith(".pptx")) return "application/vnd.openxmlformats-officedocument.presentationml.presentation";
        if (n.endsWith(".xlsx")) return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        if (n.endsWith(".pdf")) return "application/pdf";
        return "application/octet-stream";
    }

    @Override public void onRequestPermissionsResult(int code, String[] perms, int[] res) {
        super.onRequestPermissionsResult(code, perms, res);
        if (code == REQ_STORAGE && pendingDownload != null) {
            String[] d = pendingDownload; pendingDownload = null;
            if (res.length > 0 && res[0] == PackageManager.PERMISSION_GRANTED) telecharger(d[0], d[1], d[2], d[3]);
            else Toast.makeText(this, "Autorisez le stockage pour enregistrer les fichiers.", Toast.LENGTH_LONG).show();
        }
    }

    // ---------- Pont JavaScript : impression et page hors connexion ----------
    private class Pont {
        @JavascriptInterface public void imprimer(String titre) {
            runOnUiThread(() -> {
                PrintManager pm = (PrintManager) getSystemService(Context.PRINT_SERVICE);
                PrintDocumentAdapter a = Build.VERSION.SDK_INT >= 21 ? web.createPrintDocumentAdapter(titre) : null;
                if (pm != null && a != null) pm.print(titre, a, new PrintAttributes.Builder()
                        .setMediaSize(PrintAttributes.MediaSize.ISO_A4.asLandscape()).build());
            });
        }

        @JavascriptInterface public void reessayer() {
            runOnUiThread(() -> web.loadUrl(lastUrl == null ? SITE : lastUrl));
        }
    }

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }
}
