package android.jamiltz.com.photodrop;

import android.app.Activity;
import android.content.Context;

import com.couchbase.lite.LiveQuery;
import com.couchbase.lite.QueryEnumerator;

public class LiveQueryRecyclerAdapter {

    private Context context;
    private LiveQuery liveQuery;
    private QueryEnumerator enumerator;

    public LiveQueryRecyclerAdapter(Context context, LiveQuery liveQuery) {
        this.context = context;
        this.liveQuery = liveQuery;

        liveQuery.addChangeListener(new LiveQuery.ChangeListener() {
            @Override
            public void changed(LiveQuery.ChangeEvent event) {

            }
        });
    }


}
