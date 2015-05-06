package android.jamiltz.com.photodrop;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import com.couchbase.lite.Context;

import java.io.InputStream;
import java.net.URL;

public class BitmapImageUtil {

    public static Bitmap loadFrom(InputStream content) {
        return BitmapFactory.decodeStream(content);
    }

}
