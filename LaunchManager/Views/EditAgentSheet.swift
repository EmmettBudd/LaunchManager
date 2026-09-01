import AppKit
import SwiftUI

struct EditAgentSheet: View {
    let existingItem: LaunchItem?
    let defaultScope: LaunchItem.Scope
    @ObservedObject var store: AgentStore
    @Environment(\.dismiss) private var dismiss

    @State private var editorMode: EditorMode
    @State private var label: String
    @State private var program: String
    @State private var argumentRows: [ArgumentRow]
    @State private var workingDirectory: String
    @State private var triggerType: LaunchItem.TriggerType
    @State private var weekday: Int?
    @State private var hour: Int
    @State private var minute: Int
    @State private var startInterval: Int
    @State private var watchPath: String
    @State private var runAtLoad: Bool
    @State private var keepAlive: Bool
    @State private var stdoutPath: String
    @State private var stderrPath: String
    @State private var envVarRows: [EnvVarRow]
    @State private var xmlText: String
    @State private var xmlError: String?
    @State private var formDisabledReason: String?
    @State private var errorMessage: String?

    private let plistService = PlistService()

    init(
        existingItem: LaunchItem?,
        defaultScope: LaunchItem.Scope,
        store: AgentStore,
        draft: LaunchAgentDraft? = nil,
        initialXml: String? = nil
    ) {
        self.existingItem = existingItem
        self.defaultScope = defaultScope
        self.store = store

        let i = existingItem
        let d = draft

        _editorMode = State(initialValue: initialXml != nil ? .xml : .form)
        _label = State(initialValue: d?.label ?? i?.label ?? "")
        _program = State(initialValue: d?.program ?? i?.program ?? "")
        _argumentRows = State(initialValue: Self.argumentRows(from: d?.programArguments ?? i?.programArguments ?? []))
        _workingDirectory = State(initialValue: d?.workingDirectory ?? i?.workingDirectory ?? "")
        _triggerType = State(initialValue: d?.triggerType ?? i?.triggerType ?? .atLoad)
        _weekday = State(initialValue: i?.calendarInterval?.weekday)
        _hour = State(initialValue: i?.calendarInterval?.hour ?? 8)
        _minute = State(initialValue: i?.calendarInterval?.minute ?? 0)
        _startInterval = State(initialValue: i?.startInterval ?? 60)
        _watchPath = State(initialValue: i?.watchPaths.first ?? "")
        _runAtLoad = State(initialValue: d?.runAtLoad ?? i?.runAtLoad ?? false)
        _keepAlive = State(initialValue: d?.keepAlive ?? i?.keepAlive ?? false)
        _stdoutPath = State(initialValue: i?.standardOutPath ?? "")
        _stderrPath = State(initialValue: i?.standardErrorPath ?? "")
        _envVarRows = State(initialValue: Self.envRows(from: i?.environmentVariables ?? [:]))
        _xmlText = State(initialValue: initialXml ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("编辑模式", selection: $editorMode) {
                Text("表单").tag(EditorMode.form)
                Text("XML").tag(EditorMode.xml)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .onChange(of: editorMode) { _, mode in
                switch mode {
                case .xml:
                    loadXmlFromCurrentState()
                case .form:
                    syncFormFromXmlIfPossible()
                }
            }

            if editorMode == .form {
                if let reason = formDisabledReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                formContent
            } else {
                xmlContent
            }

            if existingItem == nil {
                templatesFooter
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .navigationTitle(existingItem == nil ? "新建 Agent" : "编辑 Agent")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { saveItem() }
                    .disabled(!canSave)
            }
        }
        .alert("错误", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            if editorMode == .xml && xmlText.isEmpty {
                loadXmlFromCurrentState()
            }
            validateXmlText()
            checkFormCompatibilityFromDisk()
        }
        .onChange(of: xmlText) { _, _ in
            validateXmlText()
        }
    }

    private var formContent: some View {
        Form {
            Section("基本信息") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            HStack(spacing: 0) {
                                Text("Label").font(.caption).foregroundStyle(.secondary)
                                Text(" *").font(.caption).foregroundStyle(.red)
                            }
                            InfoButton(text: "可以是任意字符串，只需在你的 Launch Agent 中保持唯一——它是 launchd 用来标识任务的 ID，也会作为生成的 .plist 文件名。反向域名写法（如 com.example.mytask）只是常见的命名约定，用来避免撞名，并非强制要求。")
                        }
                        TextField("如 com.example.mytask", text: $label)
                            .textFieldStyle(.roundedBorder)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 0) {
                            Text("程序路径").font(.caption).foregroundStyle(.secondary)
                            Text(" *").font(.caption).foregroundStyle(.red)
                        }
                        HStack {
                            TextField("如 /usr/local/bin/mytool", text: $program)
                                .textFieldStyle(.roundedBorder)
                            Button("选择…") { pickProgram() }
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("参数 Arguments").font(.caption).foregroundStyle(.secondary)
                            InfoButton(text: "启动程序时传递给它的命令行参数，每个参数一行，顺序会保留。留空表示不传递任何参数。")
                        }
                        if argumentRows.isEmpty {
                            Text("无参数").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach($argumentRows) { $row in
                            HStack(spacing: 8) {
                                TextField("参数", text: $row.value)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    argumentRows.removeAll { $0.id == row.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        Button {
                            argumentRows.append(ArgumentRow())
                        } label: {
                            Label("添加参数", systemImage: "plus")
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("工作目录").font(.caption).foregroundStyle(.secondary)
                            InfoButton(text: "程序启动时所在的当前工作目录。当脚本或程序依赖相对路径时才需要设置（例如读取与自身同目录下的配置文件），大多数情况下留空即可，会使用系统默认目录。")
                        }
                        TextField("WorkingDirectory（可选）", text: $workingDirectory)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Section("触发方式") {
                Picker("类型", selection: $triggerType) {
                    ForEach(LaunchItem.TriggerType.allCases, id: \.self) {
                        Text($0.localizedName).tag($0)
                    }
                }
                .pickerStyle(.segmented)

                switch triggerType {
                case .calendar:
                    HStack {
                        Text("星期")
                        Picker("", selection: $weekday) {
                            Text("每天").tag(Int?.none)
                            ForEach(1...7, id: \.self) { d in
                                Text(["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"][d])
                                    .tag(Int?.some(d))
                            }
                        }
                        .frame(width: 80)
                        Spacer()
                        Text("时间")
                        TextField("时", value: $hour, format: .number).frame(width: 44)
                        Text(":")
                        TextField("分", value: $minute, format: .number).frame(width: 44)
                    }
                case .interval:
                    HStack {
                        Text("每隔")
                        TextField("秒", value: $startInterval, format: .number).frame(width: 80)
                        Text("秒执行一次")
                    }
                case .watchPath:
                    TextField("监视路径", text: $watchPath)
                case .atLoad:
                    Text("登录或加载时执行一次").foregroundStyle(.secondary)
                }
            }

            Section("选项") {
                Toggle("加载时自动运行", isOn: $runAtLoad)
                Toggle("保持存活（崩溃后自动重启）", isOn: $keepAlive)
            }

            Section {
                if envVarRows.isEmpty {
                    Text("无环境变量").font(.caption).foregroundStyle(.secondary)
                }
                ForEach($envVarRows) { $row in
                    HStack(spacing: 8) {
                        TextField("KEY", text: $row.key)
                            .textFieldStyle(.roundedBorder)
                        TextField("value", text: $row.value)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            envVarRows.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button {
                    envVarRows.append(EnvVarRow())
                } label: {
                    Label("添加变量", systemImage: "plus")
                }
            } header: {
                HStack(spacing: 4) {
                    Text("环境变量 EnvironmentVariables（可选）")
                    InfoButton(text: "只在该程序运行期间生效的环境变量，不影响系统或其他程序。常用于传递密钥、开关某个功能，或覆盖 PATH 等场景。")
                }
            }

            Section {
                HStack {
                    TextField("标准输出 StandardOutPath", text: $stdoutPath)
                    Button("选择…") { pickLogFolder(for: .stdout) }
                }
                HStack {
                    TextField("标准错误 StandardErrorPath", text: $stderrPath)
                    Button("选择…") { pickLogFolder(for: .stderr) }
                }
            } header: {
                HStack(spacing: 4) {
                    Text("日志路径（可选）")
                    InfoButton(text: "程序的标准输出/标准错误写入的日志文件路径。点击「选择…」挑选一个文件夹后，会自动在其中生成以 Label 命名的日志文件（<Label>.out.log / <Label>.err.log）。留空则不记录日志。")
                }
            }
        }
        .formStyle(.grouped)
        .disabled(formDisabledReason != nil)
    }

    private var xmlContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $xmlText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 280)
                .padding(4)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
                .padding(.horizontal)

            if let xmlError {
                Text(xmlError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var canSave: Bool {
        switch editorMode {
        case .form:
            return formDisabledReason == nil && !label.isEmpty && !program.isEmpty
        case .xml:
            return xmlError == nil && !xmlText.isEmpty
        }
    }

    private var templatesFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                if let url = URL(string: "https://www.launchmanager.dev/templates") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("浏览 Launch Agent 模板…", systemImage: "safari")
            }
            .buttonStyle(.link)
            .padding(.vertical, 10)
        }
    }

    private func pickProgram() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            program = url.path
        }
    }

    private enum LogStream {
        case stdout
        case stderr
    }

    private func pickLogFolder(for stream: LogStream) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let slug = label.isEmpty ? "agent" : label
        let filename: String
        switch stream {
        case .stdout: filename = "\(slug).out.log"
        case .stderr: filename = "\(slug).err.log"
        }
        let path = url.appendingPathComponent(filename).path
        switch stream {
        case .stdout: stdoutPath = path
        case .stderr: stderrPath = path
        }
    }

    private func loadXmlFromCurrentState() {
        if let existingItem {
            xmlText = (try? plistService.readXml(from: existingItem.plistURL)) ?? formGeneratedXml()
        } else {
            xmlText = formGeneratedXml()
        }
        validateXmlText()
    }

    private func formGeneratedXml() -> String {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: plistService.toDictionary(formLaunchItem()),
            format: .xml,
            options: 0
        ), let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func syncFormFromXmlIfPossible() {
        formDisabledReason = nil
        switch plistService.validateXml(xmlText) {
        case .failure:
            formDisabledReason = String(localized: "当前 plist 含表单无法完整表示的内容，请使用 XML 模式编辑。")
        case .success(let dict):
            if let reason = plistService.formIncompatibilityReason(for: dict) {
                formDisabledReason = reason
                return
            }
            guard let parsed = parseLaunchItem(from: dict) else {
                formDisabledReason = String(localized: "当前 plist 含表单无法完整表示的内容，请使用 XML 模式编辑。")
                return
            }
            applyFormFields(from: parsed)
        }
    }

    private func checkFormCompatibilityFromDisk() {
        guard editorMode == .form, let existingItem else { return }
        guard let dict = try? plistService.readDictionary(from: existingItem.plistURL) else { return }
        formDisabledReason = plistService.formIncompatibilityReason(for: dict)
    }

    private static func envRows(from variables: [String: String]) -> [EnvVarRow] {
        variables.keys.sorted().map { EnvVarRow(key: $0, value: variables[$0] ?? "") }
    }

    private static func argumentRows(from arguments: [String]) -> [ArgumentRow] {
        arguments.map { ArgumentRow(value: $0) }
    }

    private var argumentsFromRows: [String] {
        argumentRows.map(\.value).filter { !$0.isEmpty }
    }

    private var environmentVariablesFromRows: [String: String] {
        envVarRows.reduce(into: [:]) { result, row in
            let key = row.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { return }
            result[key] = row.value
        }
    }

    private func parseLaunchItem(from dict: [String: Any]) -> LaunchItem? {
        guard let label = dict["Label"] as? String else { return nil }

        var program = ""
        var programArguments: [String] = []
        if let args = dict["ProgramArguments"] as? [String], !args.isEmpty {
            program = args[0]
            programArguments = Array(args.dropFirst())
        } else if let prog = dict["Program"] as? String {
            program = prog
        } else {
            return nil
        }

        var triggerType: LaunchItem.TriggerType = .atLoad
        var calendarInterval: LaunchItem.CalendarInterval?
        var startInterval: Int?
        var watchPaths: [String] = []

        if let ci = dict["StartCalendarInterval"] as? [String: Int] {
            triggerType = .calendar
            calendarInterval = LaunchItem.CalendarInterval(
                weekday: ci["Weekday"],
                hour: ci["Hour"],
                minute: ci["Minute"] ?? 0
            )
        } else if let si = dict["StartInterval"] as? Int {
            triggerType = .interval
            startInterval = si
        } else if let wp = dict["WatchPaths"] as? [String] {
            triggerType = .watchPath
            watchPaths = wp
        }

        let scope = existingItem?.scope ?? defaultScope
        let plistURL = existingItem?.plistURL ?? scope.directoryURL.appendingPathComponent("\(label).plist")

        return LaunchItem(
            label: label,
            plistURL: plistURL,
            scope: scope,
            program: program,
            programArguments: programArguments,
            triggerType: triggerType,
            calendarInterval: calendarInterval,
            startInterval: startInterval,
            watchPaths: watchPaths,
            runAtLoad: dict["RunAtLoad"] as? Bool ?? false,
            keepAlive: dict["KeepAlive"] as? Bool ?? false,
            standardOutPath: dict["StandardOutPath"] as? String,
            standardErrorPath: dict["StandardErrorPath"] as? String,
            workingDirectory: dict["WorkingDirectory"] as? String,
            environmentVariables: plistService.parseEnvironmentVariables(dict["EnvironmentVariables"]),
            isLoaded: existingItem?.isLoaded ?? false,
            isDisabledByOverride: existingItem?.isDisabledByOverride ?? false,
            pid: existingItem?.pid,
            lastExitCode: existingItem?.lastExitCode
        )
    }

    private func applyFormFields(from item: LaunchItem) {
        label = item.label
        program = item.program
        argumentRows = Self.argumentRows(from: item.programArguments)
        workingDirectory = item.workingDirectory ?? ""
        triggerType = item.triggerType
        weekday = item.calendarInterval?.weekday
        hour = item.calendarInterval?.hour ?? 8
        minute = item.calendarInterval?.minute ?? 0
        startInterval = item.startInterval ?? 60
        watchPath = item.watchPaths.first ?? ""
        runAtLoad = item.runAtLoad
        keepAlive = item.keepAlive
        stdoutPath = item.standardOutPath ?? ""
        stderrPath = item.standardErrorPath ?? ""
        envVarRows = Self.envRows(from: item.environmentVariables)
    }

    private func validateXmlText() {
        switch plistService.validateXml(xmlText) {
        case .success:
            xmlError = nil
        case .failure(let err):
            xmlError = err.localizedDescription
        }
    }

    private func formLaunchItem() -> LaunchItem {
        let scope = existingItem?.scope ?? defaultScope
        let args = argumentsFromRows
        let plistURL = existingItem?.plistURL ??
            scope.directoryURL.appendingPathComponent("\(label).plist")

        return LaunchItem(
            label: label,
            plistURL: plistURL,
            scope: scope,
            program: program,
            programArguments: args,
            triggerType: triggerType,
            calendarInterval: triggerType == .calendar
                ? LaunchItem.CalendarInterval(weekday: weekday, hour: hour, minute: minute)
                : nil,
            startInterval: triggerType == .interval ? startInterval : nil,
            watchPaths: triggerType == .watchPath ? [watchPath] : [],
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            standardOutPath: stdoutPath.isEmpty ? nil : stdoutPath,
            standardErrorPath: stderrPath.isEmpty ? nil : stderrPath,
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            environmentVariables: environmentVariablesFromRows,
            isLoaded: existingItem?.isLoaded ?? false,
            isDisabledByOverride: existingItem?.isDisabledByOverride ?? false,
            pid: existingItem?.pid,
            lastExitCode: existingItem?.lastExitCode
        )
    }

    private func saveItem() {
        let scope = existingItem?.scope ?? defaultScope

        if editorMode == .xml {
            guard case .success(let dict) = plistService.validateXml(xmlText),
                  let label = dict["Label"] as? String else {
                errorMessage = xmlError ?? String(localized: "Invalid plist")
                return
            }
            let plistURL = existingItem?.plistURL ??
                scope.directoryURL.appendingPathComponent("\(label).plist")
            do {
                try store.saveRawXml(xmlText, to: plistURL, scope: scope)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        do {
            try store.save(formLaunchItem())
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum EditorMode: String, CaseIterable {
    case form
    case xml
}

private struct EnvVarRow: Identifiable {
    let id = UUID()
    var key: String
    var value: String

    init(key: String = "", value: String = "") {
        self.key = key
        self.value = value
    }
}

private struct ArgumentRow: Identifiable {
    let id = UUID()
    var value: String

    init(value: String = "") {
        self.value = value
    }
}
