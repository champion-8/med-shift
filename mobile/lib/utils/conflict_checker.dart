import '../models/job_model.dart';
import '../core/enums/status_enums.dart';

class ConflictChecker {
  /// Checks if a new job conflicts with any existing hired jobs
  /// Returns true if there is a conflict, false otherwise
  static bool hasTimeConflict({
    required JobModel newJob,
    required List<JobModel> hiredJobs,
  }) {
    for (final job in hiredJobs) {
      // Only check jobs that the staff is hired for
      if (job.status != JobStatus.confirmed) continue;

      // Check if time ranges overlap
      if (_isTimeOverlapping(
        newJob.startTime,
        newJob.endTime,
        job.startTime,
        job.endTime,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Gets all conflicting jobs for a given job
  static List<JobModel> getConflictingJobs({
    required JobModel newJob,
    required List<JobModel> hiredJobs,
  }) {
    final conflicts = <JobModel>[];

    for (final job in hiredJobs) {
      if (job.status != JobStatus.confirmed) continue;

      if (_isTimeOverlapping(
        newJob.startTime,
        newJob.endTime,
        job.startTime,
        job.endTime,
      )) {
        conflicts.add(job);
      }
    }

    return conflicts;
  }

  /// Check if two time ranges overlap
  static bool _isTimeOverlapping(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    // Case 1: New job starts during existing job
    if (start1.isAfter(start2) && start1.isBefore(end2)) {
      return true;
    }

    // Case 2: New job ends during existing job
    if (end1.isAfter(start2) && end1.isBefore(end2)) {
      return true;
    }

    // Case 3: New job completely contains existing job
    if (start1.isBefore(start2) && end1.isAfter(end2)) {
      return true;
    }

    // Case 4: Exact match or start/end at same time
    if (start1.isAtSameMomentAs(start2) || end1.isAtSameMomentAs(end2)) {
      return true;
    }

    return false;
  }

  /// Get a detailed conflict message
  static String getConflictMessage(List<JobModel> conflicts) {
    if (conflicts.isEmpty) {
      return 'No conflicts';
    }

    if (conflicts.length == 1) {
      final job = conflicts.first;
      return 'Conflicts with "${job.title}" at ${job.hospitalName}';
    }

    return 'Conflicts with ${conflicts.length} scheduled jobs';
  }

  /// Check if a job can be applied to considering buffer time
  /// Buffer time is added before and after each job (e.g., 30 minutes for travel)
  static bool hasConflictWithBuffer({
    required JobModel newJob,
    required List<JobModel> hiredJobs,
    Duration bufferTime = const Duration(minutes: 30),
  }) {
    for (final job in hiredJobs) {
      if (job.status != JobStatus.confirmed) continue;

      final bufferedStart = job.startTime.subtract(bufferTime);
      final bufferedEnd = job.endTime.add(bufferTime);

      if (_isTimeOverlapping(
        newJob.startTime,
        newJob.endTime,
        bufferedStart,
        bufferedEnd,
      )) {
        return true;
      }
    }
    return false;
  }
}
