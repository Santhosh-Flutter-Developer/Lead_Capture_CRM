import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/constants/src/enum.dart';
import 'package:leadcapture/models/src/attendance_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/models.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'package:timeago/timeago.dart' as timeago;

const Color kBgColor = Color(0xFFF4F7FE);
const Color kCardColor = Colors.white;
const Color kTextPrimary = Color(0xFF2B3674);
const Color kTextSecondary = Color(0xFFA3AED0);
const double kBorderRadius = 20.0;

class Dashboard extends StatefulWidget {
  final bool isAdmin;

  const Dashboard({super.key, required this.isAdmin});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String _selectedFilter = "Today";
  final Map<String, PermissionModel?> _permissions = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final pages = [
      'Leads',
      'Deals',
      'Tasks',
      'Employees',
      'Contacts',
      'Company',
      'Tickets',
    ];
    for (var page in pages) {
      _permissions[page] = await PermissionService.getPermissions(page);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: WaitingLoading());
          }

          if (state is DashboardError) {
            return Center(
              child: Text(
                state.message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }

          if (state is DashboardLoaded) {
            final data = state.data;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(widget.isAdmin),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (kIsMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildKpiGrid(
                                context,
                                widget.isAdmin,
                                data,
                                _permissions,
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable:
                                    AppSettingsNotifier.payrollEnabled,
                                builder: (context, payrollEnabled, _) {
                                  if (!payrollEnabled)
                                    return const SizedBox.shrink();
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                      _buildPayroll(
                                        context,
                                        widget.isAdmin,
                                        data,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              if (widget.isAdmin) ...[
                                LeadsSourcePieChart(leads: data.allLeads),
                                const SizedBox(height: 20),
                                DealsTimelineChart(deals: data.allDeals),
                                const SizedBox(height: 20),
                                TaskStatusPieChart(tasks: data.allTasks),
                                const SizedBox(height: 20),
                              ],
                              _buildActivitySection(
                                // This one does not need permissions
                                context,
                                widget.isAdmin,
                                data,
                              ),
                              const SizedBox(height: 20),
                              _buildRightPanel(
                                context,
                                widget.isAdmin,
                                data,
                                _permissions,
                              ),
                            ],
                          );
                        }

                        // Desktop/Tablet Layout
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildKpiGrid(
                                    context,
                                    widget.isAdmin,
                                    data,
                                    _permissions,
                                  ),
                                  ValueListenableBuilder<bool>(
                                    valueListenable:
                                        AppSettingsNotifier.payrollEnabled,
                                    builder: (context, payrollEnabled, _) {
                                      if (!payrollEnabled)
                                        return const SizedBox.shrink();
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 20),
                                          _buildPayroll(
                                            context,
                                            widget.isAdmin,
                                            data,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  if (widget.isAdmin) ...[
                                    LeadsSourcePieChart(leads: data.allLeads),
                                    const SizedBox(height: 20),
                                    DealsTimelineChart(deals: data.allDeals),
                                    const SizedBox(height: 20),
                                    TaskStatusPieChart(tasks: data.allTasks),
                                    const SizedBox(height: 20),
                                  ],
                                  _buildActivitySection(
                                    context,
                                    widget.isAdmin,
                                    data,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 30),
                            Expanded(
                              flex: 2,
                              child: _buildRightPanel(
                                context,
                                widget.isAdmin,
                                data,
                                _permissions,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildHeader(bool isAdmin) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (VersionService.version?.isUpdateNeed ?? false)
                _buildAppUpdateContainer(),
              Text(
                "Dashboard",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isAdmin ? "Overview Analytics" : "My Workspace",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        _buildDateFilter(context),
      ],
    );
  }

  Widget _buildPayroll(
    BuildContext context,
    bool isAdmin,
    DashboardModel data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Payroll Overview",
          style: Theme.of(context).textTheme.titleMedium,
        ),

        const SizedBox(height: 15),

        /// Today Attendance
        _todayAttendanceCard(data.todayAttendance),

        const SizedBox(height: 20),

        /// Attendance Chart
        _attendanceChart(data),

        const SizedBox(height: 20),

        /// Role based widgets
        isAdmin ? _adminPayrollWidgets(data) : _employeePayrollWidgets(data),
      ],
    );
  }

  Widget _todayAttendanceCard(PunchModel? today) {
    String checkIn = "--";
    String checkOut = "--";
    if (today != null && today.punchTime.isNotEmpty) {
      List<DateTime> punches = today.punchTime
          .map((e) => DateTime.tryParse(e))
          .whereType<DateTime>()
          .toList();

      punches.sort();

      if (punches.isNotEmpty) {
        checkIn = TimeOfDay.fromDateTime(punches.first).format(context);
      }

      if (punches.length > 1) {
        checkOut = TimeOfDay.fromDateTime(punches.last).format(context);
      }
    }

    final status = today?.status ?? "";

    Color statusColor;
    switch (status.toLowerCase()) {
      case "present":
        statusColor = Colors.green;
        break;
      case "absent":
        statusColor = Colors.red;
        break;
      case "leave":
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Attendance",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// CHECK IN / OUT
          Row(
            children: [
              Expanded(
                child: _attendanceItem(
                  Icons.login,
                  "Check In",
                  checkIn,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _attendanceItem(
                  Icons.logout,
                  "Check Out",
                  checkOut,
                  Colors.red,
                ),
              ),
              Expanded(
                child: _attendanceItem(
                  Icons.access_time,
                  "Worktime",
                  today?.totalHours ?? "--",
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attendanceItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _attendanceChart(DashboardModel data) {
    return Card(
      child: SizedBox(
        height: 220,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BarChart(
            BarChartData(
              barGroups: [
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: data.attendanceStats.presentDays.toDouble(),
                      color: Colors.green,
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 2,
                  barRods: [
                    BarChartRodData(
                      toY: data.attendanceStats.absentDays.toDouble(),
                      color: Colors.green,
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 3,
                  barRods: [
                    BarChartRodData(
                      toY: data.attendanceStats.leaveDays.toDouble(),
                    ),
                  ],
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      switch (value.toInt()) {
                        case 1:
                          return const Text("Present");
                        case 2:
                          return const Text("Absent");
                        case 3:
                          return const Text("Leave");
                      }
                      return const Text("");
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _employeePayrollWidgets(DashboardModel data) {
    return Column(
      children: [
        _worktimeProgress(data),

        const SizedBox(height: 20),

        _salarySummary(data),
      ],
    );
  }

  Widget _worktimeProgress(DashboardModel data) {
    final worked = _timeToHours(data.attendanceStats.totalWorkingHours);
    final required = data.attendanceStats.presentDays * 8;
    double percent = required == 0 ? 0 : (worked / required).clamp(0, 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Monthly Work Progress",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$worked / $required hrs"),
              Text("${(percent * 100).toInt()}%"),
            ],
          ),
        ],
      ),
    );
  }

  double _timeToHours(String time) {
    if (time.isEmpty) return 0;

    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;

    return h + (m / 60);
  }

  Widget _salarySummary(DashboardModel data) {
    final salary = data.salary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Salary Summary",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _salaryItem("Basic", "₹${salary.earnAmount}", Colors.blue),
              _salaryItem("Overtime", salary.otHours, Colors.green),
              _salaryItem("Deduction", "₹${salary.totalDeduction}", Colors.red),
            ],
          ),

          const Divider(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Net Salary",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "₹${salary.netPay}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _salaryItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _adminPayrollWidgets(DashboardModel data) {
    return Column(
      children: [
        _employeeAttendanceStats(data),

        const SizedBox(height: 20),

        // _pendingApprovals(data),

        // const SizedBox(height: 20),

        // _overtimeSummary(data),
      ],
    );
  }

  Widget _employeeAttendanceStats(DashboardModel data) {
    final stats = data.attendanceStats;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Attendance Stats",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text("Present Days : ${stats.presentDays}"),
            Text("Absent Days : ${stats.absentDays}"),
            Text("Leave Days : ${stats.leaveDays}"),
            Text("Late Days : ${stats.lateDays}"),
          ],
        ),
      ),
    );
  }

  // Widget _pendingApprovals(DashboardModel data) {
  //   return Card(
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         children: [
  //           const Text(
  //             "Pending Payroll Approvals",
  //             style: TextStyle(fontWeight: FontWeight.bold),
  //           ),

  //           const SizedBox(height: 10),

  //           Text(
  //             "Permission Requests : ${data.attendanceStats.permissionsPending}",
  //           ),
  //           Text("Leave Requests : ${data.attendanceStats.leavePending}"),
  //           Text("Overtime Requests : ${data.attendanceStats.otPending}"),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _overtimeSummary(DashboardModel data) {
  //   final ot = data
  //       .attendanceStats
  //       .overtime;

  //   return Card(
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text(
  //             "Overtime Summary",
  //             style: TextStyle(fontWeight: FontWeight.bold),
  //           ),
  //           const SizedBox(height: 10),
  //           Text("Total OT Hours: ${ot.totalHours}"),
  //           Text("Approved OT: ${ot.approvedHours}"),
  //           Text("Pending OT: ${ot.pendingHours}"),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildDateFilter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff303030) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedFilter,
            icon: const Icon(Icons.arrow_drop_down),
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            style: Theme.of(context).textTheme.bodySmall,
            items: const [
              DropdownMenuItem(value: "Today", child: Text("Today")),
              DropdownMenuItem(value: "This Week", child: Text("This Week")),
              DropdownMenuItem(value: "This Month", child: Text("This Month")),
              DropdownMenuItem(
                value: "Custom Date",
                child: Text("Custom Date"),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;

              setState(() => _selectedFilter = value);

              DateTimeRange? range;

              if (value == "Custom Date") {
                range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
              }
              context.read<DashboardBloc>().add(
                LoadDashboardEvent(filter: value, range: range),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppUpdateContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4A90E2).withValues(alpha: 0.18),
            const Color(0xFF7F53AC).withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.system_update_alt_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update Available (v${VersionService.version?.version})",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "A newer version of the app is available. Update now for better performance, features and stability.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        if (Platform.isAndroid) {
                          Navigate.route(context, AndroidUpdate());
                        } else {
                          Uri url = Uri.parse(
                            VersionService.version?.url ?? '',
                          );
                          if (await canLaunchUrl(url)) {
                            launchUrl(url);
                          }
                        }
                      } catch (e, st) {
                        FlushBar.show(context, e.toString(), isSuccess: false);
                        await ErrorService.recordError(e, st);
                      }
                    },
                    child: Text(
                      "Update Now",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildKpiGrid(
  BuildContext context,
  bool isAdmin,
  DashboardModel data,
  Map<String, PermissionModel?> permissions,
) {
  // Define distinct colors for visual separation
  final blueGradient = [const Color(0xFF4285F4), const Color(0xFF6A88E5)];
  final purpleGradient = [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)];
  final orangeGradient = [const Color(0xFFFF9966), const Color(0xFFFF5E62)];
  final greenGradient = [const Color(0xFF56ab2f), const Color(0xFFa8e063)];

  return ScrollConfiguration(
    behavior: const _HorizontalDragScrollBehavior(),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: isAdmin
            ? [
                SizedBox(
                  width: 200,
                  child: KpiCard(
                    title: "Total Leads",
                    value: data.totalLeads.toString(),
                    icon: Icons.bar_chart_rounded,
                    progress: _calculateProgress(data.totalLeads, 200),
                    gradientColors: blueGradient,
                    trend: 12.5,
                    enabled: permissions['Leads']?.canView ?? true,
                    onTap: () => _openSheet(context, const LeadsListing()),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 200,
                  child: KpiCard(
                    title: "Converted",
                    value: data.convertedLeads.toString(),
                    icon: Icons.check_circle_outline_rounded,
                    progress: _calculateProgress(
                      data.convertedLeads,
                      data.totalLeads,
                    ),
                    gradientColors: greenGradient,
                    trend: 5.2,
                    enabled: permissions['Deals']?.canView ?? true,
                    onTap: () => _openSheet(context, const DealsListing()),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 200,
                  child: KpiCard(
                    title: "Ongoing Deals",
                    value: data.ongoingDeals.toString(),
                    icon: Icons.work_outline_rounded,
                    progress: _calculateProgress(data.ongoingDeals, 50),
                    gradientColors: orangeGradient,
                    trend: -2.4,
                    enabled: permissions['Deals']?.canView ?? true,
                    onTap: () => _openSheet(context, const DealsListing()),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 200,
                  child: KpiCard(
                    title: "Active Staff",
                    value: data.activeEmployees.toString(),
                    icon: Icons.people_outline_rounded,
                    progress: _calculateProgress(data.activeEmployees, 50),
                    gradientColors: purpleGradient,
                    enabled: permissions['Employees']?.canView ?? true,
                    onTap: () => _openSheet(context, const EmployeeListing()),
                  ),
                ),
              ]
            : [
                SizedBox(
                  width: 200,
                  child: KpiCard(
                    title: "Assigned Tasks",
                    value: data.assignedTasks.toString(),
                    icon: Icons.task,
                    progress: _calculateProgress(data.assignedTasks, 20),
                    gradientColors: blueGradient,
                    enabled: permissions['Tasks']?.canView ?? true,
                    onTap: () => _openSheet(context, const TasksListing()),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 200,
                  child: KpiCard(
                    title: "Pending Follow-ups",
                    value: data.pendingFollowUps.toString(),
                    icon: Icons.history,
                    progress: _calculateProgress(data.pendingFollowUps, 20),
                    gradientColors: greenGradient,
                    enabled: permissions['Leads']?.canView ?? true,
                    onTap: () => _openSheet(context, const LeadsListing()),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 200,
                  child: KpiCard(
                    title: "Leads Assigned",
                    value: data.leadsAssigned.toString(),
                    icon: Icons.person_search,
                    progress: _calculateProgress(data.leadsAssigned, 30),
                    gradientColors: purpleGradient,
                    enabled: permissions['Leads']?.canView ?? true,
                    onTap: () => _openSheet(context, const LeadsListing()),
                  ),
                ),
              ],
      ),
    ),
  );
}

double _calculateProgress(int value, int maxValue) {
  if (maxValue == 0) return 0.0;
  final p = value / maxValue;
  return p > 1 ? 1 : p;
}

Widget _buildActivitySection(
  BuildContext context,
  bool isAdmin,
  DashboardModel data,
) {
  final List<ActivityItem> activities = data.recentActivities;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(kBorderRadius),
      boxShadow: [
        BoxShadow(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAdmin ? "Recent Activity" : "Your Activity",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            // Icon(
            //   Icons.more_horiz,
            //   color: Theme.of(context).colorScheme.onSurfaceVariant,
            // ),
          ],
        ),
        const SizedBox(height: 20),
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "No activity yet.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          separatorBuilder: (_, _) => const SizedBox(height: 15),
          itemBuilder: (context, index) => ActivityTimelineTile(
            activity: activities[index],
            isFirst: index == 0,
          ),
        ),
      ],
    ),
  );
}

Widget _buildRightPanel(
  BuildContext context,
  bool isAdmin,
  DashboardModel data,
  Map<String, PermissionModel?> permissions,
) {
  final notifications = data.notifications;
  final upcomingTasks = data.upcomingTasks;
  // Sort tickets by createdAt descending and take first 5
  final tickets = List<CustomerTicketModel>.from(data.allTickets)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final recentTickets = tickets.take(5).toList();

  return LayoutBuilder(
    builder: (context, constraints) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 80, // controls card height
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    (isAdmin
                            ? _adminActions(context, permissions)
                            : _userActions(context, permissions))
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(right: 15),
                            child: SizedBox(
                              width: 80, // fixed width per card
                              child: card,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔔 NOTIFICATIONS
          _sectionTitle(context, "Notifications"),
          const SizedBox(height: 15),

          if (notifications.isEmpty)
            _emptyText(context, "No new notifications.")
          else
            ...notifications.map((msg) => NotificationTile(notification: msg)),

          const SizedBox(height: 20),

          // 🎫 TICKETS
          _sectionTitle(context, "Recent Tickets"),
          const SizedBox(height: 15),

          if (recentTickets.isEmpty)
            _emptyText(context, "No tickets yet.")
          else
            ...recentTickets.map(
              (ticket) => TicketTile(
                ticket: ticket,
                onTap: () => _openSheet(context, TicketView(uid: ticket.uid!)),
              ),
            ),

          const SizedBox(height: 20),

          // 📌 TASKS
          _sectionTitle(context, isAdmin ? "Upcoming Deadlines" : "Your Tasks"),
          const SizedBox(height: 15),

          if (upcomingTasks.isEmpty)
            _emptyText(context, "No upcoming tasks.")
          else
            ...upcomingTasks.map(
              (item) => TaskReminderTile(
                title: item.title,
                date: DateFormat(
                  'dd MMM yyyy, hh:mm a',
                ).format(item.scheduledAt),
                isOverdue: item.scheduledAt.isBefore(DateTime.now()),
                onTap: () => _openUpcomingItem(context, item),
              ),
            ),
        ],
      );
    },
  );
}

Future<void> _openUpcomingItem(
  BuildContext context,
  UpcomingDeadlineItemModel item,
) async {
  final Widget widget;
  if (item.source == 'event') {
    widget = EventEdit(uid: item.id);
  } else if (item.source == 'ticket') {
    widget = TicketView(uid: item.id);
  } else {
    widget = TaskView(uid: item.id);
  }

  if (kIsMobile) {
    await Sheet.showSheet(context, widget: widget);
  } else {
    await GeneralDialog.showRTLSheet(context, widget);
  }
}

Widget _sectionTitle(BuildContext context, String text) {
  return Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

Widget _emptyText(BuildContext context, String text) {
  return Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

List<Widget> _adminActions(
  BuildContext context,
  Map<String, PermissionModel?> permissions,
) => [
  QuickActionCard(
    icon: Icons.add_circle_outline,
    label: "Add Lead",
    color: Colors.blue,
    enabled: permissions['Leads']?.canCreate ?? true,
    onTap: () => _openSheet(context, const LeadCreate()),
  ),
  QuickActionCard(
    icon: Icons.work_outline,
    label: "Add Deal",
    color: Colors.purple,
    enabled: permissions['Deals']?.canCreate ?? true,
    onTap: () => _openSheet(context, const DealCreate()),
  ),
  QuickActionCard(
    icon: Icons.check_circle_outline,
    label: "Add Task",
    color: Colors.orange,
    enabled: permissions['Tasks']?.canCreate ?? true,
    onTap: () => _openSheet(context, const TaskCreate(employees: [])),
  ),
  QuickActionCard(
    icon: Icons.confirmation_number_outlined,
    label: "Add Ticket",
    color: Colors.teal,
    enabled: permissions['Tickets']?.canCreate ?? true,
    onTap: () => _openSheet(context, const TicketCreate()),
  ),

  // QuickActionCard(
  //   icon: Icons.access_time,
  //   label: "Attendance",
  //   color: Colors.green,
  //   onTap: () => _openSheet(context, const Attendance()),
  // ),

  // QuickActionCard(
  //   icon: Icons.payments_outlined,
  //   label: "Salary Ledger",
  //   color: Colors.indigo,
  //   onTap: () => _openSheet(context, const SalaryLedgerList()),
  // ),

  // QuickActionCard(
  //   icon: Icons.verified_user_outlined,
  //   label: "Permissions",
  //   color: Colors.red,
  //   onTap: () => _openSheet(context, const PermissionRequestsListing()),
  // ),
];

List<Widget> _userActions(
  BuildContext context,
  Map<String, PermissionModel?> permissions,
) => [
  // QuickActionCard(
  //   icon: Icons.login,
  //   label: "Worktime",
  //   color: Colors.green,
  //   onTap: () => _openSheet(context, const WorktimeCreate()),
  // ),

  // QuickActionCard(
  //   icon: Icons.calendar_today,
  //   label: "Attendance",
  //   color: Colors.blue,
  //   onTap: () => _openSheet(context, const Attendance()),
  // ),
  // QuickActionCard(
  //   icon: Icons.person_add_outlined,
  //   label: "Lead",
  //   color: Colors.blue,
  //   enabled: permissions['Leads']?.canCreate ?? true,
  //   onTap: () => _openSheet(context, const LeadCreate()),
  // ),
  QuickActionCard(
    icon: Icons.update,
    label: "Tasks",
    color: Colors.orange,
    enabled: permissions['Tasks']?.canView ?? true,
    onTap: () => _openSheet(context, const TasksListing()),
  ),
  QuickActionCard(
    icon: Icons.confirmation_number_outlined,
    label: "Add Ticket",
    color: Colors.teal,
    enabled: permissions['Tickets']?.canCreate ?? true,
    onTap: () => _openSheet(context, const TicketCreate()),
  ),
  QuickActionCard(
    icon: Icons.chat_bubble_outline,
    label: "Chat",
    color: Colors.green,
    onTap: () async {
      var uid = await Spdb.getUid() ?? '';
      _openSheet(context, ChatListing(currentUserUid: uid));
    },
  ),
];

void _openSheet(BuildContext context, Widget widget) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;

    if (kIsMobile) {
      Sheet.showSheet(context, widget: widget);
    } else {
      GeneralDialog.showRTLSheet(context, widget);
    }
  });
}

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final double progress;
  final List<Color> gradientColors;
  final double? trend;
  final VoidCallback onTap;
  final bool enabled;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.progress,
    required this.gradientColors,
    this.trend,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = (trend ?? 0) >= 0;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ─── HEADER ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),

                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPositive
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 16,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${trend!.abs()}%",
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isPositive ? Colors.green : Colors.red,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              /// ─── VALUE ───────────────────────────────
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const Spacer(),

              /// ─── PROGRESS ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Target",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: gradientColors.first,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        gradientColors.first,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool enabled;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color = Colors.blue,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        splashColor: enabled
            ? color.withValues(alpha: 0.15)
            : Colors.transparent,
        highlightColor: enabled
            ? color.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// ICON
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 16, color: Colors.white),
                  ),

                  const SizedBox(height: 6),

                  /// LABEL
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationTile extends StatefulWidget {
  final NotificationModel notification;

  const NotificationTile({super.key, required this.notification});

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  Color _iconColor() {
    switch (widget.notification.type ?? NotificationType.info) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.ticket:
        return Colors.teal;
      case NotificationType.info:
      default:
        return Colors.blue;
    }
  }

  IconData _iconData() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.ticket:
        return Icons.confirmation_number_outlined;
      case NotificationType.info:
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Future<void> _openPlatformSheet(BuildContext context, Widget widget) async {
    if (kIsDesktop) {
      await GeneralDialog.showRTLSheet(context, widget);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => widget));
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    // debugPrint('=== Dashboard notification tapped ===');
    // debugPrint('Type: ${widget.notification.type}');
    // debugPrint('Title: ${widget.notification.title}');
    // debugPrint('Payload: ${widget.notification.payload}');
    // debugPrint('====================================');

    if (widget.notification.payload['ticketId'] != null &&
        (widget.notification.payload['ticketId'] as String).isNotEmpty) {
      debugPrint('Found ticketId in payload (dashboard), opening TicketView');
      await _openPlatformSheet(
        context,
        TicketView(uid: widget.notification.payload['ticketId'] as String),
      );
      return;
    }

    switch (widget.notification.type) {
      case NotificationType.chat:
        final chatId = widget.notification.collectionId;
        final senderId = widget.notification.senderId ?? '';

        if (chatId!.isNotEmpty) {
          await _openPlatformSheet(
            context,
            ChatListing(currentUserUid: senderId, selectedChatUid: chatId),
          );
        }
        break;

      case NotificationType.task:
        final taskId = widget.notification.payload['taskId'] as String?;

        if (taskId != null && taskId.isNotEmpty) {
          await _openPlatformSheet(context, TaskView(uid: taskId));
        } else {
          await _openPlatformSheet(context, TasksListing());
        }
        break;

      case NotificationType.ticket:
        final ticketId = widget.notification.payload['ticketId'] as String?;

        if (ticketId != null && ticketId.isNotEmpty) {
          await _openPlatformSheet(context, TicketView(uid: ticketId));
        } else {
          // If no ticketId, open tickets listing
          await _openPlatformSheet(context, const TicketsListing());
        }
        break;

      /// 📊 LEAD
      case NotificationType.lead:
        final leadId = widget.notification.payload['leadId'] as String?;

        if (leadId != null && leadId.isNotEmpty) {
          try {
            final lead = await LeadService.getLead(uid: leadId);

            await _openPlatformSheet(context, LeadsViewPage(lead: lead));
          } catch (_) {
            await _openPlatformSheet(context, LeadsListing(showAppBar: true));
          }
        }
        break;

      /// 💼 DEAL
      case NotificationType.deal:
        final dealId = widget.notification.payload['dealId'] as String?;

        if (dealId != null && dealId.isNotEmpty) {
          try {
            final deal = await DealService.getDeal(uid: dealId);

            await _openPlatformSheet(context, DealsViewPage(deal: deal));
          } catch (_) {
            await _openPlatformSheet(context, DealsListing(showAppBar: true));
          }
        }
        break;

      /// 📰 FEED
      case NotificationType.feed:
        await _openPlatformSheet(context, FeedListing());
        break;

      /// 📅 EVENT
      case NotificationType.eventReminder:
        await _openPlatformSheet(context, CalendarEventScreen());
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _iconColor();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _handleTap(context),

      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ICON
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.12),
              ),
              child: Icon(_iconData(), color: iconColor, size: 22),
            ),

            const SizedBox(width: 12),

            /// CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    widget.notification.createdAt!.formatDateMonthTime,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskReminderTile extends StatelessWidget {
  final String title;
  final String date;
  final bool isOverdue;
  final VoidCallback? onTap;

  const TaskReminderTile({
    super.key,
    required this.title,
    required this.date,
    this.isOverdue = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isOverdue ? Colors.red : Colors.orange;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              /// ICON
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.9),
                      accentColor.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              /// CONTENT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              /// STATUS / ARROW
              Row(
                children: [
                  if (isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Overdue",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketTile extends StatelessWidget {
  final CustomerTicketModel ticket;
  final VoidCallback? onTap;

  const TicketTile({super.key, required this.ticket, this.onTap});

  Color _statusColor() {
    switch (ticket.status) {
      case TicketStatus.open:
        return Colors.blue;
      case TicketStatus.inProgress:
        return Colors.orange;
      case TicketStatus.closed:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon() {
    switch (ticket.status) {
      case TicketStatus.open:
        return Icons.confirmation_number_outlined;
      case TicketStatus.inProgress:
        return Icons.work_outline;
      case TicketStatus.closed:
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              /// ICON
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.9),
                      statusColor.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Icon(_statusIcon(), color: Colors.white, size: 20),
              ),

              const SizedBox(width: 12),

              /// CONTENT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.ticketTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(ticket.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              /// STATUS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ticket.status.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityTimelineTile extends StatelessWidget {
  final ActivityItem activity;
  final bool isFirst;

  const ActivityTimelineTile({
    super.key,
    required this.activity,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isFirst ? Colors.blue : Colors.grey.shade300,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  if (isFirst)
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 2,
                    ),
                ],
              ),
            ),
            Container(width: 2, height: 20, color: Colors.grey.shade200),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 0), // Align with dot
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.page,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isFirst
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isFirst ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                Text(
                  timeago.format(activity.visitedAt, locale: 'en_short'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isFirst
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isFirst ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HorizontalDragScrollBehavior extends MaterialScrollBehavior {
  const _HorizontalDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}
