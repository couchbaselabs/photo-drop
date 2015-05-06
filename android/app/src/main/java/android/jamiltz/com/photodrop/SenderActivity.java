package android.jamiltz.com.photodrop;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.os.Parcelable;
import android.support.annotation.NonNull;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;

import com.couchbase.lite.CouchbaseLiteException;
import com.couchbase.lite.Database;
import com.couchbase.lite.Document;
import com.couchbase.lite.Manager;
import com.couchbase.lite.UnsavedRevision;
import com.couchbase.lite.android.AndroidContext;
import com.couchbase.lite.replicator.Replication;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.Result;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.EnumMap;
import java.util.Iterator;
import java.util.List;
import java.util.ListIterator;

import me.dm7.barcodescanner.zbar.ZBarScannerView;
import me.dm7.barcodescanner.zxing.ZXingScannerView;


public class SenderActivity extends Activity implements ZBarScannerView.ResultHandler {

    private String TAG = "scanner";
    private ZBarScannerView mScannerView;
    public Parcelable[] uris;

    private Manager manager;
    private Database database;

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        mScannerView = new ZBarScannerView(this);    // Programmatically initialize the scanner view
        setContentView(mScannerView);                // Set the scanner view as the content view

        uris = getIntent().getParcelableArrayExtra("uris");

        try {
            manager = new Manager(new AndroidContext(getApplicationContext()), Manager.DEFAULT_OPTIONS);
        } catch (IOException e) {
            e.printStackTrace();
        }

        database = DatabaseHelper.getEmptyDatabase("db", manager);

    }

    @Override
    public void onResume() {
        super.onResume();
        mScannerView.setResultHandler(this); // Register ourselves as a handler for scan results.
        mScannerView.startCamera();          // Start camera on resume
    }

    @Override
    public void onPause() {
        super.onPause();
        mScannerView.stopCamera();           // Stop camera on pause
    }

    @Override
    public void handleResult(me.dm7.barcodescanner.zbar.Result result) {
        // Do something with the result here
        Log.v(TAG, result.getContents()); // Prints scan results
        Log.v(TAG, result.getBarcodeFormat().getName()); // Prints the scan format (qrcode, pdf417 etc.)

        String stringUrl = result.getContents();
        try {
            URL url = new URL(stringUrl);
            replication(url);
        } catch (MalformedURLException e) {
            e.printStackTrace();
        }
    }

    void replication(URL url) {
        // for loop to get the image
        ArrayList<String> documentIds = new ArrayList();
        for (Parcelable path : uris) {
            Bitmap image = BitmapFactory.decodeFile(path.toString());

            Document document = database.createDocument();
            UnsavedRevision revision = document.createRevision();

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            image.compress(Bitmap.CompressFormat.JPEG, 50, out);
            ByteArrayInputStream in = new ByteArrayInputStream(out.toByteArray());

            revision.setAttachment("photo", "application/octet-stream", in);

            try {
                revision.save();
                documentIds.add(0, document.getId());
            } catch (CouchbaseLiteException e) {
                e.printStackTrace();
            }
        }

        System.out.println("The documents IDs are " +  documentIds.toString());

        if (documentIds.size() > 0) {
            Replication push = database.createPushReplication(url);
            push.setDocIds(documentIds);
            push.start();
        }

    }

}
