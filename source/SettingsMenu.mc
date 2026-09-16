using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;

class SettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.AppName)});
        for(var i=0;i<SettingsCatalog.KEYS.size();i+=1) {
            var opts=SettingsCatalog.choices(i) as Lang.Array<Lang.Array>;
            var current=Application.Properties.getValue(SettingsCatalog.KEYS[i]);
            var label="--";
            for(var j=0;j<opts.size();j+=1) {
                if(opts[j][0]==current) { label=WatchUi.loadResource(opts[j][1]); break; }
            }
            addItem(new WatchUi.MenuItem(WatchUi.loadResource(SettingsCatalog.TITLES[i]),label,i,{}));
        }
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var index=item.getId() as Lang.Number;
        var options=SettingsCatalog.choices(index) as Lang.Array<Lang.Array>;
        var menu=new WatchUi.Menu2({:title=>WatchUi.loadResource(SettingsCatalog.TITLES[index])});
        var current=Application.Properties.getValue(SettingsCatalog.KEYS[index]);
        for(var i=0;i<options.size();i+=1) {
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(options[i][1]),null,options[i][0],{}));
            if(options[i][0]==current) { menu.setFocus(i); }
        }
        WatchUi.pushView(menu,new ChoiceDelegate(index,item),WatchUi.SLIDE_IMMEDIATE);
    }
}

class ChoiceDelegate extends WatchUi.Menu2InputDelegate {
    var index;
    var parentItem;
    function initialize(i,item) { Menu2InputDelegate.initialize(); index=i; parentItem=item; }
    function onSelect(item) {
        Application.Properties.setValue(SettingsCatalog.KEYS[index],item.getId());
        parentItem.setSubLabel(item.getLabel());
        Application.getApp().onSettingsChanged();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
