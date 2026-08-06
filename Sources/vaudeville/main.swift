import AppKit

struct Options {
    var delay: Double? = nil
    var silent = false
    var curtainsOnly = false
    var restore = true
    var text = "INTERMISSION"
    var preview: String? = nil
    var renderIcon: String? = nil

    /// Launched from Spotlight/Finder (i.e. as a bundle), give the launcher UI
    /// a beat to get out of the way before the hook enters.
    var resolvedDelay: Double {
        delay ?? (Bundle.main.bundleIdentifier != nil ? 0.75 : 0)
    }
}

func printUsage() {
    print("""
    vaudeville — give the frontmost window the hook, then bring down the curtain

    usage: vaudeville [options]
      --delay <seconds>   wait before the show starts (time to front the victim window)
      --curtains-only     skip the hook; just drop and raise the curtain
      --silent            no slide whistle, no thud
      --no-restore        leave the yanked window in the wings afterward
      --text <string>     curtain text (default "INTERMISSION"; "" for none)
      --preview [dir]     render hook.png + curtain.png to dir (default ./preview) and exit
      --render-icon <p>   render the app icon PNG to path p and exit (used by packaging)
      --help              this

    Dragging a real window needs Accessibility permission for your terminal:
    System Settings → Privacy & Security → Accessibility.
    """)
}

func parseOptions() -> Options {
    var o = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let a = args.removeFirst()
        switch a {
        case "--delay":
            o.delay = args.isEmpty ? 0 : (Double(args.removeFirst()) ?? 0)
        case "--render-icon":
            guard !args.isEmpty else {
                FileHandle.standardError.write(Data("vaudeville: --render-icon needs a path\n".utf8))
                exit(2)
            }
            o.renderIcon = args.removeFirst()
        case "--silent":
            o.silent = true
        case "--curtains-only":
            o.curtainsOnly = true
        case "--no-restore":
            o.restore = false
        case "--text":
            o.text = args.isEmpty ? "" : args.removeFirst()
        case "--preview":
            if let next = args.first, !next.hasPrefix("--") {
                o.preview = args.removeFirst()
            } else {
                o.preview = "./preview"
            }
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            FileHandle.standardError.write(Data("vaudeville: unknown option \(a)\n".utf8))
            printUsage()
            exit(2)
        }
    }
    return o
}

let options = parseOptions()

if let dir = options.preview {
    exit(Preview.run(dir: dir))
}

if let path = options.renderIcon {
    guard let image = Icon.render() else {
        FileHandle.standardError.write(Data("vaudeville: icon render failed\n".utf8))
        exit(1)
    }
    Preview.writePNG(image, to: path)
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let options: Options
    var show: TheShow?

    init(options: Options) { self.options = options }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + options.resolvedDelay) { [self] in start() }
    }

    private func start() {
        var target: GrabbedWindow? = nil
        if !options.curtainsOnly {
            if AXTarget.isTrusted(promptIfNeeded: true) {
                target = AXTarget.frontmostWindow()
                if target == nil {
                    print("vaudeville: no front window to hook — the hook will mime it.")
                }
            } else {
                print("""
                vaudeville: no Accessibility permission, so the hook can't drag a real window \
                (the curtain still falls). Grant it in System Settings → Privacy & Security → \
                Accessibility — add your terminal — then run again.
                """)
            }
        }
        let screen = target.flatMap { t in NSScreen.screens.first { $0.frame.intersects(t.frame) } }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let show = TheShow(config: .init(silent: options.silent,
                                         curtainsOnly: options.curtainsOnly,
                                         restore: options.restore,
                                         text: options.text))
        self.show = show
        show.begin(on: screen, target: target)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate(options: options)
app.delegate = delegate

// Ctrl-C mid-show shouldn't strand the victim's window in the wings.
signal(SIGINT, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler {
    delegate.show?.emergencyRestore()
    exit(130)
}
sigint.resume()

app.run()
