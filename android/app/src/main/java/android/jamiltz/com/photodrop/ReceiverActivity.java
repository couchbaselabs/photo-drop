package android.jamiltz.com.photodrop;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.text.format.Formatter;
import android.widget.ImageView;

import com.couchbase.lite.Attachment;
import com.couchbase.lite.CouchbaseLiteException;
import com.couchbase.lite.Database;
import com.couchbase.lite.Document;
import com.couchbase.lite.DocumentChange;
import com.couchbase.lite.Manager;
import com.couchbase.lite.android.AndroidContext;
import com.couchbase.lite.listener.LiteListener;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;

import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.EnumMap;
import java.util.List;

public class ReceiverActivity extends Activity {

    private Manager manager;
    private Database database;
    private LiteListener listener;

    private List<Bitmap> assets;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_receive);

        try {
            manager = new Manager(new AndroidContext(getApplicationContext()), Manager.DEFAULT_OPTIONS);
        } catch (IOException e) {
            e.printStackTrace();
        }

        database = DatabaseHelper.getEmptyDatabase("db", manager);

        startListener();

        startObserveDatabaseChange();

        URL url = null;
        try {
            url = new URL("http", getLocalIpAddress(), listener.getListenPort(), "/db");
        } catch (MalformedURLException e) {
            e.printStackTrace();
        }

        System.out.println("Listening on :: " + url.toString());
        encode(url.toString());
    }

    void startObserveDatabaseChange() {
        database.addChangeListener(new Database.ChangeListener() {
            @Override
            public void changed(Database.ChangeEvent event) {

                List<DocumentChange> changes = event.getChanges();

                for (DocumentChange change : changes) {
                    System.out.println("Id of the changing doc " + change.getDocumentId());
                    saveImageFromDocument(change.getDocumentId());
                }

            }
        });
    }

    void saveImageFromDocument(String name) {
        Document document = database.getExistingDocument(name);

        Bitmap bitmap = null;
        List<Attachment> attachments = document.getCurrentRevision().getAttachments();
        if (attachments != null && attachments.size() > 0) {
            Attachment attachment = attachments.get(0);

            // convert to Bitmap
            try {
                bitmap = BitmapFactory.decodeStream(attachment.getContent());
            } catch (CouchbaseLiteException e) {
                e.printStackTrace();
            }

            // add the image to the recycler view list
            assets.add(bitmap);

            // the recycler view on the bottom part.

            // call notifyDataInsert with the image

        }

    }

    void startListener() {
        listener = new LiteListener(manager, 5432, null);
        Thread thread = new Thread(listener);
        thread.start();
    }

    public String getLocalIpAddress() {
        WifiManager wm = (WifiManager) getSystemService(WIFI_SERVICE);
        return Formatter.formatIpAddress(wm.getConnectionInfo().getIpAddress());
    }

    private void encode(String uniqueID) {
        // TODO Auto-generated method stub
        BarcodeFormat barcodeFormat = BarcodeFormat.QR_CODE;

        int width0 = 500;
        int height0 = 500;

        int colorBack = 0xFF000000;
        int colorFront = 0xFFFFFFFF;

        QRCodeWriter writer = new QRCodeWriter();
        try
        {
            EnumMap<EncodeHintType, Object> hint = new EnumMap<EncodeHintType, Object>(EncodeHintType.class);
            hint.put(EncodeHintType.CHARACTER_SET, "UTF-8");
            BitMatrix bitMatrix = writer.encode(uniqueID, barcodeFormat, width0, height0, hint);
            int width = bitMatrix.getWidth();
            int height = bitMatrix.getHeight();
            int[] pixels = new int[width * height];
            for (int y = 0; y < height; y++)
            {
                int offset = y * width;
                for (int x = 0; x < width; x++)
                {

                    pixels[offset + x] = bitMatrix.get(x, y) ? colorBack : colorFront;
                }
            }

            Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            bitmap.setPixels(pixels, 0, width, 0, 0, width, height);
            ImageView imageview = (ImageView)findViewById(R.id.qrCode);
            imageview.setImageBitmap(bitmap);
        } catch (WriterException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }

}
