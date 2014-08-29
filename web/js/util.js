
/***********************
* Methods
***********************/

// create a string.format function to make our life easier
if (!(typeof "".format === "function")) {
    String.prototype.format = function () {
        var args = arguments;
        return this.replace(/\{(\d+)\}/g, function (m, n) { return args[n]; });
    };
}

// create a string.format function to make our life easier
if (!(typeof Date.format === "function")) {
    Date.prototype.format = function (fmt) {
        fmt = fmt || "yyyymmdd";
        var yyyy = this.getFullYear();
        var mm = this.getMonth() + 1;
        if (mm < 10) mm = "0" + mm;
        var dd = this.getDate();
        if (dd < 10) dd = "0" + dd;

        switch (fmt) {
            case "mmdd":
                return "" + mm + "/" + dd;
                break;

            case "mmddyyyy":
                return "" + mm + "-" + dd + "-" + yyyy;
                break;

            case "yyyymmdd":
            default:
                return yyyy + "-" + mm + "-" + dd;
                break;
        }
    };
}