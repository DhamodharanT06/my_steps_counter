package app.dynamicdragon.mystepcounter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget, built the way the home_widget plugin's own docs show
 * it: extend [HomeWidgetProvider] (its convenience base class) rather than
 * hand-rolling the SharedPreferences lookup. Android hands this the widget
 * data directly as [widgetData] — no separate plumbing needed.
 *
 * One resizable widget rather than two separate ones: drag it wide for a
 * rectangle, or square for a compact tile — same layout, same code, and one
 * receiver to register instead of two, which is a lot less that can go wrong.
 *
 * A RemoteViews widget can't run a live Flutter animation, so instead of one
 * continuous animation it swaps between four fixed icons (resting / walking
 * / running / goal-reached) as your activity changes.
 */
class StepWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val steps = widgetData.getInt("steps", 0)
        val goal = widgetData.getInt("goal", 8000)
        val state = widgetData.getString("state", "resting") ?: "resting"

        val icon = when (state) {
            "goal" -> R.drawable.ic_widget_goal
            "running" -> R.drawable.ic_widget_run
            "walking" -> R.drawable.ic_widget_walk
            else -> R.drawable.ic_widget_rest
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.step_widget)
            views.setTextViewText(R.id.widget_steps, "%,d".format(steps))
            views.setTextViewText(R.id.widget_goal, "of %,d steps".format(goal))
            views.setImageViewResource(R.id.widget_icon, icon)

            // The plugin's own helper builds the "open the app" PendingIntent,
            // so there's no manual package-lookup code to get wrong.
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
