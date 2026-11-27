package com.cercadeaqui.app;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.net.Uri;
import android.view.View;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import android.content.Intent;
import android.net.http.SslError;
import android.webkit.SslErrorHandler;

import androidx.webkit.WebViewAssetLoader;

public class MainActivity extends Activity {
    private static final String HOME = "https://appassets.androidplatform.net/assets/index.html";
    private WebView webView;
    private WebViewAssetLoader assetLoader;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(Color.rgb(16, 23, 43));
        getWindow().setNavigationBarColor(Color.rgb(16, 23, 43));
        assetLoader = new WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
            .build();

        webView = new WebView(this);
        webView.setBackgroundColor(Color.WHITE);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSupportZoom(false);
        settings.setBuiltInZoomControls(false);
        settings.setUserAgentString(settings.getUserAgentString() + " CercaDeAquiAndroid/1.0");
        webView.setWebViewClient(new WebViewClient() {
            @Override public android.webkit.WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assetLoader.shouldInterceptRequest(request.getUrl());
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String scheme = uri.getScheme() == null ? "" : uri.getScheme();
                String host = uri.getHost() == null ? "" : uri.getHost();
                if ("https".equals(scheme) && "appassets.androidplatform.net".equals(host)) return false;
                if ("cercadeaqui".equals(scheme) && "auth-callback".equals(host)) {
                    openLocalWithAuth(uri);
                    return true;
                }
                if ("https".equals(scheme) || "http".equals(scheme) || "mailto".equals(scheme) || "tel".equals(scheme)) {
                    try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); } catch (Exception ignored) {}
                    return true;
                }
                return true;
            }
            @Override public void onPageFinished(WebView view, String url) {
                view.evaluateJavascript("document.querySelectorAll('a[target=_blank]').forEach(a=>a.target='_self')", null);
            }
            @Override public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
                handler.cancel();
            }
        });
        setContentView(webView);
        loadHomeFromIntent(getIntent());
    }

    private void loadHomeFromIntent(Intent intent) {
        Uri data = intent == null ? null : intent.getData();
        if (data != null && "cercadeaqui".equals(data.getScheme()) && "auth-callback".equals(data.getHost())) {
            openLocalWithAuth(data);
        } else {
            webView.loadUrl(HOME);
        }
    }

    private void openLocalWithAuth(Uri callback) {
        String fragment = callback.getEncodedFragment();
        String query = callback.getEncodedQuery();
        String suffix = fragment != null ? "#" + fragment : (query != null ? "?" + query : "");
        webView.loadUrl(HOME + suffix);
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        loadHomeFromIntent(intent);
    }

    @Override public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
