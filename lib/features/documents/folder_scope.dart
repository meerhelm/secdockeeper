enum FolderScopeKind { all, unassigned, specific }

class FolderScope {
  const FolderScope.all()
      : id = null,
        kind = FolderScopeKind.all;
  const FolderScope.unassigned()
      : id = null,
        kind = FolderScopeKind.unassigned;
  const FolderScope.specific(int folderId)
      : id = folderId,
        kind = FolderScopeKind.specific;

  final int? id;
  final FolderScopeKind kind;

  bool get isAll => kind == FolderScopeKind.all;
  bool get isUnassigned => kind == FolderScopeKind.unassigned;
  int? get specificId => kind == FolderScopeKind.specific ? id : null;

  @override
  bool operator ==(Object other) =>
      other is FolderScope && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}
