import Testing
@testable import Containers

struct PrivilegedRunnerTests {
    @Test func posixQuotingNeutralizesSingleQuotes() {
        #expect(PrivilegedRunner.posixQuoted("safe") == "'safe'")
        #expect(PrivilegedRunner.posixQuoted("a'b") == "'a'\\''b'")
        // A classic injection payload collapses into one inert, fully-quoted literal argument.
        #expect(PrivilegedRunner.posixQuoted("'; rm -rf / #") == "''\\''; rm -rf / #'")
    }

    @Test func appleScriptEscapesBothLayers() {
        let script = PrivilegedRunner.appleScript(for: [
            "/usr/local/bin/container", "system", "dns", "create", "x';touch /tmp/pwned;'",
        ])
        #expect(script.hasPrefix("do shell script \""))
        #expect(script.hasSuffix("\" with administrator privileges"))
        // Backslashes and double quotes from the shell layer must be escaped for the AppleScript literal.
        let dangerous = PrivilegedRunner.appleScript(for: ["echo", "a\"b\\c"])
        #expect(dangerous.contains("\\\""))
        #expect(dangerous.contains("\\\\"))
    }

    @Test func dnsValidationRejectsInjectionPayloads() {
        #expect(DNSStore.isValidDomain("test"))
        #expect(DNSStore.isValidDomain("my.local"))
        #expect(!DNSStore.isValidDomain("x';touch /tmp/pwned;'"))
        #expect(!DNSStore.isValidDomain("-leadingdash"))
        #expect(!DNSStore.isValidDomain("trailing."))
        #expect(!DNSStore.isValidDomain(""))
        #expect(DNSStore.isValidAddress("127.0.0.1"))
        #expect(DNSStore.isValidAddress("fde5:97ab::1"))
        #expect(!DNSStore.isValidAddress("1.2.3.4; rm -rf /"))
    }
}
