using MedShift.Application.Interfaces;
using Microsoft.AspNetCore.Hosting;

namespace MedShift.Infrastructure.Storage;

public class LocalFileStorage(IWebHostEnvironment env) : IFileStorage
{
    public async Task<string> SaveAsync(
        Stream content,
        string folder,
        string fileName,
        CancellationToken ct = default)
    {
        var webRoot = string.IsNullOrWhiteSpace(env.WebRootPath)
            ? Path.Combine(env.ContentRootPath, "wwwroot")
            : env.WebRootPath;

        var safeFolder = folder.Replace('\\', '/').Trim('/');
        var dir = Path.Combine(webRoot, safeFolder.Replace('/', Path.DirectorySeparatorChar));
        Directory.CreateDirectory(dir);

        var physicalPath = Path.Combine(dir, fileName);
        await using (var stream = File.Create(physicalPath))
        {
            await content.CopyToAsync(stream, ct);
        }

        return $"/{safeFolder}/{fileName}";
    }
}
