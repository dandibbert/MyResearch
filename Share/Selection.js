// Safari invokes this only on an explicit share. No page body is collected.
var ExtensionPreprocessingJS = {
    run: function (args) {
        args.completionFunction({
            selection: String(window.getSelection() || "").slice(0, 32768),
            url: String(document.URL || "")
        });
    }
};
