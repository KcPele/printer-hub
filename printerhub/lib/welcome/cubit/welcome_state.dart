part of 'welcome_cubit.dart';

class WelcomeState extends Equatable {
  const new({this.page = 0, this.finished = false});

  /// The welcome screen in view, from zero.
  final int page;

  /// True once the user has left the welcome screens for good.
  final bool finished;

  bool get isLastPage => page == WelcomeCubit.pageCount - 1;

  WelcomeState copyWith({int? page, bool? finished}) {
    return WelcomeState(
      page: page ?? this.page,
      finished: finished ?? this.finished,
    );
  }

  @override
  List<Object> get props => [page, finished];
}
