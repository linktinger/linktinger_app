import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../widgets/projects/project_card.dart';
import '../../services/project_service.dart';
import 'create_project_screen.dart';
import 'project_details_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> projects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProjects();
  }

  Future<void> fetchProjects() async {
    setState(() => isLoading = true);
    final data = await ProjectService.fetchAllProjects();
    setState(() {
      projects = data;
      isLoading = false;
    });
  }

  void _goToCreateProject() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
    );
    if (result == true) {
      fetchProjects();
    }
  }

  void _openProjectDetails(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: project)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'المشاريع',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF142B63),
        onPressed: _goToCreateProject,
        tooltip: 'إضافة مشروع جديد',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : projects.isEmpty
          ? const Center(
              child: Text(
                "لا توجد مشاريع بعد",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: const Color(0xFF1E293B),
              onRefresh: fetchProjects,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: projects.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return GestureDetector(
                    onTap: () => _openProjectDetails(project),
                    child: ProjectCard(project: project),
                  );
                },
              ),
            ),
    );
  }
}
