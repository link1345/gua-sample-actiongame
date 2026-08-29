using Gua.Testing;
using Gua.Testing.Godot;
using NUnit.Framework;

namespace GuaSignalRelay.Tests;

[TestFixture]
[NonParallelizable]
public sealed class MissionUiTests
{
    private static readonly TimeSpan UiTimeout = TimeSpan.FromSeconds(5);
    private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(20);
    private static readonly string ProjectRoot = FindProjectRoot();

    [Test]
    public async Task AiStartsMissionAndUnlocksDoorThroughLiveSemanticUi()
    {
        using var host = StartHost();
        using var assertions = GuaAssertionScope.Use(new GuaAssertionOptions
        {
            DiagnosticsSession = host.CreateDiagnosticsSession(
                TestContext.CurrentContext.Test.FullName,
                Path.Combine(TestContext.CurrentContext.WorkDirectory, "artifacts", "gua")),
        });

        await GuaAssertions.WaitForVisibleAsync(
            host.Context,
            "play-game",
            timeout: UiTimeout,
            pollInterval: PollInterval);
        Assert.Throws<InvalidOperationException>(() => host.Context.FindNodeById("human-message-draft"));
        Assert.Throws<InvalidOperationException>(() => host.Context.FindNodeById("agent-message-draft"));
        GuaAssertions.GetById(host.Context, "title-game-description").ToBeVisible();
        GuaAssertions.GetById(host.Context, "title-human-role").ToBeVisible();
        GuaAssertions.GetById(host.Context, "title-ai-role").ToBeVisible();
        GuaAssertions.GetById(host.Context, "title-start-restriction").ToBeVisible();
        var titleWorld = host.RemoteContext.GetWorldObjectTree().Objects;
        Assert.That(titleWorld, Is.Not.Empty);
        Assert.That(
            titleWorld.All(item => !item.VisibleToPlayer),
            Is.True,
            "Every mission world object must be hidden from the Player projection on the title.");

        await GuaAssertions.GetById(host.Context, "play-game")
            .ClickAsync(timeout: UiTimeout, pollInterval: PollInterval);
        await GuaAssertions.WaitForVisibleAsync(
            host.Context,
            "reactor-current",
            timeout: UiTimeout,
            pollInterval: PollInterval);
        Assert.Throws<InvalidOperationException>(() => host.Context.FindNodeById("human-message-draft"));
        Assert.Throws<InvalidOperationException>(() => host.Context.FindNodeById("agent-message-draft"));
        await GuaAssertions.WaitForDisabledAsync(
            host.Context,
            "door-a-control",
            timeout: UiTimeout,
            pollInterval: PollInterval);

        var missionWorld = host.RemoteContext.GetWorldObjectTree().Objects;
        Assert.That(missionWorld.All(item => item.VisibleToPlayer), Is.True);
        var worldIds = missionWorld.Select(item => item.Id)
            .ToArray();
        Assert.That(worldIds, Is.EquivalentTo(new[]
        {
            "sector-a",
            "field-operator",
            "door-a",
            "laser-staging-zone",
            "laser-array",
            "extraction-zone",
            "exit-airlock",
        }));

        await GuaAssertions.GetById(host.Context, "shield-enabled")
            .SetCheckedAsync(true, timeout: UiTimeout, pollInterval: PollInterval);
        await GuaAssertions.GetById(host.Context, "reactor-current")
            .SetValueAsync("85", timeout: UiTimeout, pollInterval: PollInterval);
        await GuaAssertions.WaitForEnabledAsync(
            host.Context,
            "door-a-control",
            timeout: UiTimeout,
            pollInterval: PollInterval);
        await GuaAssertions.GetById(host.Context, "door-a-control")
            .ClickAsync(timeout: UiTimeout, pollInterval: PollInterval);

        await GuaAssertions.WaitForVisibleAsync(
            host.Context,
            "door-a-open",
            timeout: UiTimeout,
            pollInterval: PollInterval);
        GuaAssertions.GetById(host.Context, "laser-suppression-requirement").ToBeVisible();
        GuaAssertions.GetById(host.Context, "laser-suppression-remaining").ToBeVisible();
    }

    private static GodotSceneTestHost StartHost()
    {
        return GodotSceneTestHost.Load("res://scenes/main.tscn", new GodotSceneTestHostOptions
        {
            ProjectPath = ProjectRoot,
            UseAvailableBridgePort = true,
            StartupResetPolicy = GuaResetPolicy.Strict,
            TeardownResetPolicy = GuaResetPolicy.Strict,
            CaptureDiagnosticsBeforeTeardown = true,
            CleanupAfterLeakReport = true,
        });
    }

    private static string FindProjectRoot()
    {
        var directory = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "project.godot")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("Could not find project.godot above the test output directory.");
    }
}
