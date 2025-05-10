import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fungiscan/domain/repositories/mushroom_repository.dart';

// Events
abstract class CommunityEvent extends Equatable {
  const CommunityEvent();

  @override
  List<Object?> get props => [];
}

class LoadCommunityPosts extends CommunityEvent {
  const LoadCommunityPosts();
}

class CreatePost extends CommunityEvent {
  final String title;
  final String description;
  final String? imageUrl;
  final String userId;

  const CreatePost({
    required this.title,
    required this.description,
    this.imageUrl,
    required this.userId,
  });

  @override
  List<Object?> get props => [title, description, imageUrl, userId];
}

class LikePost extends CommunityEvent {
  final String postId;
  final String userId;

  const LikePost({
    required this.postId,
    required this.userId,
  });

  @override
  List<Object?> get props => [postId, userId];
}

class CommentOnPost extends CommunityEvent {
  final String postId;
  final String userId;
  final String comment;

  const CommentOnPost({
    required this.postId,
    required this.userId,
    required this.comment,
  });

  @override
  List<Object?> get props => [postId, userId, comment];
}

// State
class CommunityState extends Equatable {
  final bool isLoading;
  final List<dynamic> posts;
  final String? error;

  const CommunityState({
    this.isLoading = false,
    this.posts = const [],
    this.error,
  });

  CommunityState copyWith({
    bool? isLoading,
    List<dynamic>? posts,
    String? error,
  }) {
    return CommunityState(
      isLoading: isLoading ?? this.isLoading,
      posts: posts ?? this.posts,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, posts, error];
}

class CommunityBloc extends Bloc<CommunityEvent, CommunityState> {
  final MushroomRepository mushroomRepository;
  final bool isOffline;

  CommunityBloc({
    required this.mushroomRepository,
    required this.isOffline,
  }) : super(const CommunityState()) {
    on<LoadCommunityPosts>(_onLoadCommunityPosts);
    on<CreatePost>(_onCreatePost);
    on<LikePost>(_onLikePost);
    on<CommentOnPost>(_onCommentOnPost);
  }

  Future<void> _onLoadCommunityPosts(
      LoadCommunityPosts event, Emitter<CommunityState> emit) async {
    if (isOffline) {
      emit(state.copyWith(
        error:
            "You are currently offline. Community features are not available.",
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, error: null));

    try {
      // In a real implementation, this would fetch posts from a backend
      // For now, we'll just simulate a delay and return empty posts
      await Future.delayed(const Duration(milliseconds: 500));

      emit(state.copyWith(
        isLoading: false,
        posts: [], // This would be populated with real data in a complete app
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onCreatePost(
      CreatePost event, Emitter<CommunityState> emit) async {
    if (isOffline) {
      emit(state.copyWith(
        error: "You are currently offline. Cannot create posts.",
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, error: null));

    try {
      // In a real implementation, this would create a post in the backend
      // For now, we'll just simulate a delay and add a dummy post locally
      await Future.delayed(const Duration(milliseconds: 800));

      final newPost = {
        'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
        'title': event.title,
        'description': event.description,
        'imageUrl': event.imageUrl,
        'userId': event.userId,
        'createdAt': DateTime.now().toIso8601String(),
        'likes': 0,
        'comments': <String>[],
      };

      final updatedPosts = [...state.posts, newPost];

      emit(state.copyWith(
        isLoading: false,
        posts: updatedPosts,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLikePost(LikePost event, Emitter<CommunityState> emit) async {
    if (isOffline) {
      emit(state.copyWith(
        error: "You are currently offline. Cannot like posts.",
      ));
      return;
    }

    try {
      // In a real implementation, this would update the like count in the backend
      // For now, we'll just update the like count locally
      final updatedPosts = state.posts.map((post) {
        if (post['id'] == event.postId) {
          return {
            ...post,
            'likes': (post['likes'] as int) + 1,
          };
        }
        return post;
      }).toList();

      emit(state.copyWith(posts: updatedPosts));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onCommentOnPost(
      CommentOnPost event, Emitter<CommunityState> emit) async {
    if (isOffline) {
      emit(state.copyWith(
        error: "You are currently offline. Cannot comment on posts.",
      ));
      return;
    }

    try {
      // In a real implementation, this would add a comment in the backend
      // For now, we'll just update the comments locally
      final updatedPosts = state.posts.map((post) {
        if (post['id'] == event.postId) {
          final comments = [...post['comments']];
          comments.add({
            'userId': event.userId,
            'comment': event.comment,
            'createdAt': DateTime.now().toIso8601String(),
          });

          return {
            ...post,
            'comments': comments,
          };
        }
        return post;
      }).toList();

      emit(state.copyWith(posts: updatedPosts));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
