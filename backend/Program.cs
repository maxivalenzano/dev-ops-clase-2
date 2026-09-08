using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

var portEnv = Environment.GetEnvironmentVariable("PORT");
var port = int.TryParse(portEnv, out var parsedPort) ? parsedPort : 3000;
var instanceName = Environment.GetEnvironmentVariable("INSTANCE_NAME") ?? Environment.MachineName;

builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

app.UseCors();

// State for chaos and stress testing
var isHealthy = true;
var allocatedBuffers = new List<byte[]>();
var bufferLock = new object();
var processStartTime = DateTime.UtcNow;

// Logger middleware
app.Use(async (context, next) =>
{
    var sw = Stopwatch.StartNew();
    var path = context.Request.Path;
    var method = context.Request.Method;

    await next();

    sw.Stop();
    var timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
    Console.WriteLine($"[{timestamp}] [{instanceName}] {method} {path} - {context.Response.StatusCode} ({sw.ElapsedMilliseconds}ms)");
});

// Root endpoints
IResult HandleRoot() =>
    Results.Ok(new
    {
        message = "Backend service is online",
        instance = instanceName,
        port = port,
        timestamp = DateTime.UtcNow.ToString("o")
    });

app.MapGet("/", HandleRoot);
app.MapGet("/api", HandleRoot);
app.MapGet("/api/", HandleRoot);

// Health check endpoints
IResult HandleHealth()
{
    if (isHealthy)
    {
        return Results.Ok(new
        {
            status = "UP",
            instance = instanceName,
            timestamp = DateTime.UtcNow.ToString("o")
        });
    }

    return Results.Json(new
    {
        status = "DOWN",
        instance = instanceName,
        error = "Health check manually toggled to DOWN",
        timestamp = DateTime.UtcNow.ToString("o")
    }, statusCode: StatusCodes.Status500InternalServerError);
}

app.MapGet("/health", HandleHealth);
app.MapGet("/api/health", HandleHealth);

// 1. Instance and system information
app.MapGet("/api/info", () =>
{
    using var currentProcess = Process.GetCurrentProcess();
    var workingSet = currentProcess.WorkingSet64;
    var gcInfo = GC.GetGCMemoryInfo();
    var uptimeSeconds = Math.Max(0, (long)(DateTime.UtcNow - processStartTime).TotalSeconds);

    long totalRetainedBytes;
    lock (bufferLock)
    {
        totalRetainedBytes = allocatedBuffers.Sum(b => (long)b.Length);
    }

    return Results.Ok(new
    {
        instance = instanceName,
        hostname = Environment.MachineName,
        pid = Environment.ProcessId,
        port = port,
        uptimeSeconds = uptimeSeconds,
        memory = new
        {
            rssMB = Math.Round(workingSet / 1024.0 / 1024.0, 2),
            heapTotalMB = Math.Round(gcInfo.HeapSizeBytes / 1024.0 / 1024.0, 2),
            heapUsedMB = Math.Round(GC.GetTotalMemory(false) / 1024.0 / 1024.0, 2),
            externalMB = 0.0,
            totalBuffersRetainedMB = Math.Round(totalRetainedBytes / 1024.0 / 1024.0, 2)
        },
        system = new
        {
            platform = RuntimeInformation.OSDescription,
            cpus = Environment.ProcessorCount,
            freeMemoryMB = Math.Round(gcInfo.TotalAvailableMemoryBytes / 1024.0 / 1024.0, 2),
            totalMemoryMB = Math.Round(gcInfo.HighMemoryLoadThresholdBytes / 1024.0 / 1024.0, 2)
        },
        isHealthy = isHealthy,
        timestamp = DateTime.UtcNow.ToString("o")
    });
});

// 2. Delayed response (Timeout Testing)
app.MapGet("/api/delay", async (int? ms) =>
{
    var delayMs = ms ?? 3000;
    Console.WriteLine($"[{instanceName}] Simulating delay: sleeping for {delayMs}ms...");

    await Task.Delay(delayMs);

    return Results.Ok(new
    {
        message = $"Response delayed by {delayMs}ms",
        instance = instanceName,
        delayMs = delayMs,
        timestamp = DateTime.UtcNow.ToString("o")
    });
});

// 3. CPU Stress Testing (Intense computation loop)
app.MapPost("/api/stress/cpu", (HttpRequest request, CpuStressRequest? body) =>
{
    var durationParam = request.Query["duration"].ToString();
    var durationMs = body?.Duration
                     ?? (int.TryParse(durationParam, out var d) ? d : 3000);

    Console.WriteLine($"[{instanceName}] Starting CPU stress for {durationMs}ms...");

    var sw = Stopwatch.StartNew();
    long operations = 0;
    var random = new Random();

    while (sw.ElapsedMilliseconds < durationMs)
    {
        _ = Math.Sqrt(random.NextDouble() * 1_000_000);
        operations++;
    }

    return Results.Ok(new
    {
        message = $"CPU stress completed for {durationMs}ms",
        instance = instanceName,
        operations = operations,
        durationMs = durationMs,
        timestamp = DateTime.UtcNow.ToString("o")
    });
});

// 4. Memory Stress Testing (Buffer Allocation to test container limits / OOM)
app.MapPost("/api/stress/memory", (HttpRequest request, MemoryStressRequest? body) =>
{
    var mbParam = request.Query["mb"].ToString();
    var mb = body?.Mb
             ?? (int.TryParse(mbParam, out var m) ? m : 50);

    Console.WriteLine($"[{instanceName}] Allocating {mb}MB of memory buffers...");

    try
    {
        var sizeInBytes = mb * 1024 * 1024;
        var buffer = new byte[sizeInBytes];
        Array.Fill(buffer, (byte)0x58); // 'X' - write pages to force physical memory commit

        int count;
        long totalRetainedBytes;
        lock (bufferLock)
        {
            allocatedBuffers.Add(buffer);
            count = allocatedBuffers.Count;
            totalRetainedBytes = allocatedBuffers.Sum(b => (long)b.Length);
        }

        using var proc = Process.GetCurrentProcess();
        var rssMb = Math.Round(proc.WorkingSet64 / 1024.0 / 1024.0, 2);

        return Results.Ok(new
        {
            message = $"Allocated {mb}MB successfully",
            instance = instanceName,
            chunksRetained = count,
            totalBuffersRetainedMB = Math.Round(totalRetainedBytes / 1024.0 / 1024.0, 2),
            rssMB = rssMb,
            timestamp = DateTime.UtcNow.ToString("o")
        });
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"[{instanceName}] Memory allocation failed: {ex.Message}");
        return Results.Json(new
        {
            error = "Memory allocation failed",
            message = ex.Message,
            instance = instanceName
        }, statusCode: StatusCodes.Status500InternalServerError);
    }
});

// 5. Memory release endpoint
app.MapPost("/api/stress/memory/clear", () =>
{
    int previousChunks;
    lock (bufferLock)
    {
        previousChunks = allocatedBuffers.Count;
        allocatedBuffers.Clear();
    }

    GC.Collect(2, GCCollectionMode.Aggressive, true, true);
    GC.WaitForPendingFinalizers();
    GC.Collect(2, GCCollectionMode.Aggressive, true, true);

    return Results.Ok(new
    {
        message = $"Cleared {previousChunks} retained memory chunks",
        instance = instanceName,
        chunksRetained = 0,
        timestamp = DateTime.UtcNow.ToString("o")
    });
});

// 6. Toggle Health Check status
app.MapPost("/api/health/toggle", () =>
{
    isHealthy = !isHealthy;
    Console.WriteLine($"[{instanceName}] Health state toggled. New state: {(isHealthy ? "UP" : "DOWN")}");

    return Results.Ok(new
    {
        message = $"Health status changed to {(isHealthy ? "UP" : "DOWN")}",
        isHealthy = isHealthy,
        instance = instanceName,
        timestamp = DateTime.UtcNow.ToString("o")
    });
});

app.Run();

public record CpuStressRequest([property: JsonPropertyName("duration")] int? Duration);
public record MemoryStressRequest([property: JsonPropertyName("mb")] int? Mb);
