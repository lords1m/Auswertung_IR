import os
from flask import Flask, render_template, send_from_directory, abort

app = Flask(__name__)

PLOTS_DIR = "exported_plots"
TABLES_DIR = "exported_tables"

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".svg", ".gif"}
TABLE_EXTENSIONS = {".csv", ".xlsx", ".txt"}


def list_files(directory, extensions):
    if not os.path.isdir(directory):
        return []
    return sorted(
        f for f in os.listdir(directory)
        if os.path.splitext(f)[1].lower() in extensions
    )


@app.route("/")
def index():
    plots = list_files(PLOTS_DIR, IMAGE_EXTENSIONS)
    tables = list_files(TABLES_DIR, TABLE_EXTENSIONS)
    return render_template("index.html", plots=plots, tables=tables)


@app.route("/plots/<path:filename>")
def serve_plot(filename):
    if not os.path.isdir(PLOTS_DIR):
        abort(404)
    return send_from_directory(PLOTS_DIR, filename)


@app.route("/tables/<path:filename>")
def serve_table(filename):
    if not os.path.isdir(TABLES_DIR):
        abort(404)
    return send_from_directory(TABLES_DIR, filename)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
