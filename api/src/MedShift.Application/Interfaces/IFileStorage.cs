namespace MedShift.Application.Interfaces;

/// <summary>
/// File storage abstraction. Phase 1: local disk.
/// Swap implementation to blob (Azure/S3) without changing callers.
/// </summary>
public interface IFileStorage
{
    /// <summary>Saves a file and returns a publicly served relative URL (e.g. /uploads/staff-docs/...).</summary>
    Task<string> SaveAsync(
        Stream content,
        string folder,
        string fileName,
        CancellationToken ct = default);
}
