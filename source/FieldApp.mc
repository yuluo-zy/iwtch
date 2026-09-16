using Toybox.Application;
using Toybox.WatchUi;

class FieldApp extends Application.AppBase {
    var view;
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        view = new FieldView();
        return [view, new FieldDelegate(view)];
    }
    function onSettingsChanged() {
        if (view != null) { view.settingsChanged(); }
        WatchUi.requestUpdate();
    }
    function getSettingsView() {
        return [new SettingsMenu(), new SettingsDelegate()];
    }
}

class FieldDelegate extends WatchUi.WatchFaceDelegate {
    var view;
    function initialize(v) { WatchFaceDelegate.initialize(); view = v; }
    function onPowerBudgetExceeded(powerInfo) {
        // Stop optional one-second work until next app launch.
        view.partialAllowed = false;
    }
}
