// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'query_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QueryState<V> {

 V? get data; Object? get error; QueryStatus get status; FetchStatus get fetchStatus; bool get isStale; bool get isLoadingMore;
/// Create a copy of QueryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueryStateCopyWith<V, QueryState<V>> get copyWith => _$QueryStateCopyWithImpl<V, QueryState<V>>(this as QueryState<V>, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueryState<V>&&const DeepCollectionEquality().equals(other.data, data)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.status, status) || other.status == status)&&(identical(other.fetchStatus, fetchStatus) || other.fetchStatus == fetchStatus)&&(identical(other.isStale, isStale) || other.isStale == isStale)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),const DeepCollectionEquality().hash(error),status,fetchStatus,isStale,isLoadingMore);

@override
String toString() {
  return 'QueryState<$V>(data: $data, error: $error, status: $status, fetchStatus: $fetchStatus, isStale: $isStale, isLoadingMore: $isLoadingMore)';
}


}

/// @nodoc
abstract mixin class $QueryStateCopyWith<V,$Res>  {
  factory $QueryStateCopyWith(QueryState<V> value, $Res Function(QueryState<V>) _then) = _$QueryStateCopyWithImpl;
@useResult
$Res call({
 V? data, Object? error, QueryStatus status, FetchStatus fetchStatus, bool isStale, bool isLoadingMore
});




}
/// @nodoc
class _$QueryStateCopyWithImpl<V,$Res>
    implements $QueryStateCopyWith<V, $Res> {
  _$QueryStateCopyWithImpl(this._self, this._then);

  final QueryState<V> _self;
  final $Res Function(QueryState<V>) _then;

/// Create a copy of QueryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = freezed,Object? error = freezed,Object? status = null,Object? fetchStatus = null,Object? isStale = null,Object? isLoadingMore = null,}) {
  return _then(_self.copyWith(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as V?,error: freezed == error ? _self.error : error ,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as QueryStatus,fetchStatus: null == fetchStatus ? _self.fetchStatus : fetchStatus // ignore: cast_nullable_to_non_nullable
as FetchStatus,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [QueryState].
extension QueryStatePatterns<V> on QueryState<V> {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QueryState<V> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QueryState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QueryState<V> value)  $default,){
final _that = this;
switch (_that) {
case _QueryState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QueryState<V> value)?  $default,){
final _that = this;
switch (_that) {
case _QueryState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( V? data,  Object? error,  QueryStatus status,  FetchStatus fetchStatus,  bool isStale,  bool isLoadingMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QueryState() when $default != null:
return $default(_that.data,_that.error,_that.status,_that.fetchStatus,_that.isStale,_that.isLoadingMore);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( V? data,  Object? error,  QueryStatus status,  FetchStatus fetchStatus,  bool isStale,  bool isLoadingMore)  $default,) {final _that = this;
switch (_that) {
case _QueryState():
return $default(_that.data,_that.error,_that.status,_that.fetchStatus,_that.isStale,_that.isLoadingMore);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( V? data,  Object? error,  QueryStatus status,  FetchStatus fetchStatus,  bool isStale,  bool isLoadingMore)?  $default,) {final _that = this;
switch (_that) {
case _QueryState() when $default != null:
return $default(_that.data,_that.error,_that.status,_that.fetchStatus,_that.isStale,_that.isLoadingMore);case _:
  return null;

}
}

}

/// @nodoc


class _QueryState<V> extends QueryState<V> {
  const _QueryState({this.data, this.error, this.status = QueryStatus.idle, this.fetchStatus = FetchStatus.idle, this.isStale = false, this.isLoadingMore = false}): super._();
  

@override final  V? data;
@override final  Object? error;
@override@JsonKey() final  QueryStatus status;
@override@JsonKey() final  FetchStatus fetchStatus;
@override@JsonKey() final  bool isStale;
@override@JsonKey() final  bool isLoadingMore;

/// Create a copy of QueryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QueryStateCopyWith<V, _QueryState<V>> get copyWith => __$QueryStateCopyWithImpl<V, _QueryState<V>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QueryState<V>&&const DeepCollectionEquality().equals(other.data, data)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.status, status) || other.status == status)&&(identical(other.fetchStatus, fetchStatus) || other.fetchStatus == fetchStatus)&&(identical(other.isStale, isStale) || other.isStale == isStale)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),const DeepCollectionEquality().hash(error),status,fetchStatus,isStale,isLoadingMore);

@override
String toString() {
  return 'QueryState<$V>(data: $data, error: $error, status: $status, fetchStatus: $fetchStatus, isStale: $isStale, isLoadingMore: $isLoadingMore)';
}


}

/// @nodoc
abstract mixin class _$QueryStateCopyWith<V,$Res> implements $QueryStateCopyWith<V, $Res> {
  factory _$QueryStateCopyWith(_QueryState<V> value, $Res Function(_QueryState<V>) _then) = __$QueryStateCopyWithImpl;
@override @useResult
$Res call({
 V? data, Object? error, QueryStatus status, FetchStatus fetchStatus, bool isStale, bool isLoadingMore
});




}
/// @nodoc
class __$QueryStateCopyWithImpl<V,$Res>
    implements _$QueryStateCopyWith<V, $Res> {
  __$QueryStateCopyWithImpl(this._self, this._then);

  final _QueryState<V> _self;
  final $Res Function(_QueryState<V>) _then;

/// Create a copy of QueryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = freezed,Object? error = freezed,Object? status = null,Object? fetchStatus = null,Object? isStale = null,Object? isLoadingMore = null,}) {
  return _then(_QueryState<V>(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as V?,error: freezed == error ? _self.error : error ,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as QueryStatus,fetchStatus: null == fetchStatus ? _self.fetchStatus : fetchStatus // ignore: cast_nullable_to_non_nullable
as FetchStatus,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
