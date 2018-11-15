package unit;

class TestRunner {
    public function new() {
        suites = [];

        reports = [];
    }

    public function add<T:TestSuite>(suite: Class<T>) {
        suites.push(cast Type.createInstance(suite, [this]));
    }

    public function run() {
        var report;
        for (x in suites) {
            report = x.run();
            //report[0].result.failed
        }
    }

    private var suites(default, null): Array<TestSuite>;
    private var reports(default, null): Array<Dynamic>;
}
