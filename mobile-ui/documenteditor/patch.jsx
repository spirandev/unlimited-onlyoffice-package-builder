/*
 * Copyright (C) Ascensio System SIA, 2009-2026
 *
 * This program is a free software product. You can redistribute it and/or
 * modify it under the terms of the GNU Affero General Public License (AGPL)
 * version 3 as published by the Free Software Foundation, together with the
 * additional terms provided in the LICENSE file.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. For
 * details, see the GNU AGPL at: https://www.gnu.org/licenses/agpl-3.0.html
 *
 * You can contact Ascensio System SIA by email at info@onlyoffice.com
 * or by postal mail at 20A-6 Ernesta Birznieka-Upisha Street, Riga,
 * LV-1050, Latvia, European Union.
 *
 * The interactive user interfaces in modified versions of the Program
 * are required to display Appropriate Legal Notices in accordance with
 * Section 5 of the GNU AGPL version 3.
 *
 * No trademark rights are granted under this License.
 *
 * All non-code elements of the Product, including illustrations,
 * icon sets, and technical writing content, are licensed under the
 * Creative Commons Attribution-ShareAlike 4.0 International License:
 * https://creativecommons.org/licenses/by-sa/4.0/legalcode
 *
 * This license applies only to such non-code elements and does not
 * modify or replace the licensing terms applicable to the Program's
 * source code, which remains licensed under the GNU Affero General
 * Public License v3.
 *
 * SPDX-License-Identifier: AGPL-3.0-only
 */

/*
 * Modificado em 2026 por Pandora Tecnologia (fork onlyoffice-ems-builder).
 *
 * Substitui o stub apps/documenteditor/mobile/src/lib/patch.jsx de
 * ONLYOFFICE/web-apps v9.4.0.129. Liga ao SDK a interface de edição do editor
 * mobile que já é pública (view/edit, view/add, stores). Escrito só a partir do
 * código público do ONLYOFFICE/web-apps; cada trecho indica o commit cujo pai
 * (<commit>^) tem a implementação de referência:
 *   - getToolbarOptions ............ dc4c20081 (links btn-edit/btn-add em view/Toolbar.jsx)
 *   - getUndoRedo .................. cd1aa44b5 (links icon-undo/icon-redo em view/Toolbar.jsx)
 *   - initFocusObjects/intf ........ ee15cf025 (asc_onFocusObject), 94b4ebc18 (settings),
 *                                    b0c9a1c5d (getters de store/focusObjects.js)
 *   - initFonts, initEditorStyles,
 *     initTableTemplates ........... ee15cf025 (controller/Main.jsx)
 *   - initThemeColors, updateChartStyles,
 *     getEditCommentControllers .... 45a9058da (controller/Main.jsx)
 *   - ContextMenu .................. b0c9a1c5d (controller/ContextMenu.jsx)
 * Adaptações à 9.4: props da toolbar (disabledEdit/disabledAdd), ícones SvgIcon,
 * initTableTemplates sem argumentos, opções 'add-link'/'edit-link' da página
 * principal, proteção de documento e itens de sumário no menu de toque (os
 * mesmos critérios do menu de leitura de controller/ContextMenu.jsx).
 */

import React, { Fragment } from 'react';
import { Link } from 'framework7-react';
import { Device } from '../../../../common/mobile/utils/device';
import { LocalStorage } from '../../../../common/mobile/utils/LocalStorage.mjs';
import {
    AddCommentController,
    EditCommentController
} from '../../../../common/mobile/lib/controller/collaboration/Comments';
import SvgIcon from '@common/lib/component/SvgIcon';
import IconEditSettingsIos from '@common-ios-icons/icon-edit-settings.svg?ios';
import IconEditSettingsAndroid from '@common-android-icons/icon-edit-settings.svg';
import IconPlusIos from '@common-ios-icons/icon-plus.svg?ios';
import IconPlusAndroid from '@common-android-icons/icon-plus.svg?android';
import IconUndoIos from '@common-ios-icons/icon-undo.svg?ios';
import IconUndoAndroid from '@common-android-icons/icon-undo.svg';
import IconRedoIos from '@common-ios-icons/icon-redo.svg?ios';
import IconRedoAndroid from '@common-android-icons/icon-redo.svg';
import IconCopy from '@common-icons/icon-copy.svg';
import IconCut from '@common-icons/icon-cut.svg';
import IconPaste from '@common-icons/icon-paste.svg';

const EditorUIController = () => {
    return null
};

EditorUIController.isSupportEditFeature = () => {
    return true
};

const ToolbarIcon = ({ ios, android }) => (
    <SvgIcon symbolId={Device.ios ? ios.id : android.id} className={'icon icon-svg'} />
);

EditorUIController.getToolbarOptions = ({ disabledEdit, disabledAdd, onEditClick, onAddClick }) => {
    return (
        <Fragment>
            <Link iconOnly id='btn-edit' className={disabledEdit ? 'disabled' : ''} href={false} onClick={onEditClick}>
                <ToolbarIcon ios={IconEditSettingsIos} android={IconEditSettingsAndroid} />
            </Link>
            <Link iconOnly id='btn-add' className={disabledAdd ? 'disabled' : ''} href={false} onClick={onAddClick}>
                <ToolbarIcon ios={IconPlusIos} android={IconPlusAndroid} />
            </Link>
        </Fragment>
    )
};

EditorUIController.getUndoRedo = ({ disabledUndo, disabledRedo, onUndoClick, onRedoClick }) => {
    return (
        <Fragment>
            <Link iconOnly id='btn-undo' className={disabledUndo ? 'disabled' : ''} href={false} onClick={onUndoClick}>
                <ToolbarIcon ios={IconUndoIos} android={IconUndoAndroid} />
            </Link>
            <Link iconOnly id='btn-redo' className={disabledRedo ? 'disabled' : ''} href={false} onClick={onRedoClick}>
                <ToolbarIcon ios={IconRedoIos} android={IconRedoAndroid} />
            </Link>
        </Fragment>
    )
};

EditorUIController.initThemeColors = () => {
    const api = Common.EditorApi.get();
    api.asc_registerCallback('asc_onSendThemeColors', (colors, standart_colors) => {
        Common.Utils.ThemeColor.setColors(colors, standart_colors);
    });
};

EditorUIController.initFonts = storeTextSettings => {
    const api = Common.EditorApi.get();
    api.asc_registerCallback('asc_onInitEditorFonts', (fonts, select) => {
        storeTextSettings.initEditorFonts(fonts, select);
    });
    api.asc_registerCallback('asc_onFontFamily', font => {
        storeTextSettings.resetFontName(font);
    });
    api.asc_registerCallback('asc_onFontSize', size => {
        storeTextSettings.resetFontSize(size);
    });
    api.asc_registerCallback('asc_onBold', isBold => {
        storeTextSettings.resetIsBold(isBold);
    });
    api.asc_registerCallback('asc_onItalic', isItalic => {
        storeTextSettings.resetIsItalic(isItalic);
    });
    api.asc_registerCallback('asc_onUnderline', isUnderline => {
        storeTextSettings.resetIsUnderline(isUnderline);
    });
    api.asc_registerCallback('asc_onStrikeout', isStrikeout => {
        storeTextSettings.resetIsStrikeout(isStrikeout);
    });
};

// Valor do último objeto (o de cima) da pilha de seleção que satisfaz o filtro.
const getTopObjectValue = (objects, filter) => {
    for (let i = objects.length - 1; i >= 0; i--) {
        if (filter(objects[i])) {
            return objects[i].get_ObjectValue();
        }
    }
    return undefined;
};

const isObjectType = type => object => object.get_ObjectType() == type;

// Getters de store/focusObjects.js (store.intf). Leem store._focusObjects, que é
// observável, então os computed do store continuam reativos.
const createFocusObjectsIntf = store => ({
    filterFocusObjects() {
        const _settings = [];
        for (let object of store._focusObjects) {
            const type = object.get_ObjectType();
            if (Asc.c_oAscTypeSelectElement.Paragraph === type) {
                _settings.push('text', 'paragraph');
            } else if (Asc.c_oAscTypeSelectElement.Table === type) {
                _settings.push('table');
            } else if (Asc.c_oAscTypeSelectElement.Image === type) {
                if (object.get_ObjectValue().get_ChartProperties()) {
                    // o gráfico substitui a forma
                    const si = _settings.indexOf('shape');
                    si < 0 ? _settings.push('chart') : _settings.splice(si, 1, 'chart');
                } else if (object.get_ObjectValue().get_ShapeProperties() && !_settings.includes('chart')) {
                    _settings.push('shape');
                } else {
                    _settings.push('image');
                }
            } else if (Asc.c_oAscTypeSelectElement.Hyperlink === type) {
                _settings.push('hyperlink');
            } else if (Asc.c_oAscTypeSelectElement.Header === type) {
                _settings.push('header');
            }
        }
        return _settings.filter((value, index, self) => self.indexOf(value) === index);
    },
    getHeaderObject() {
        return getTopObjectValue(store._focusObjects, isObjectType(Asc.c_oAscTypeSelectElement.Header));
    },
    getParagraphObject() {
        return getTopObjectValue(store._focusObjects, isObjectType(Asc.c_oAscTypeSelectElement.Paragraph));
    },
    getShapeObject() {
        return getTopObjectValue(store._focusObjects, object =>
            object.get_ObjectType() == Asc.c_oAscTypeSelectElement.Image &&
            !!object.get_ObjectValue() && !!object.get_ObjectValue().get_ShapeProperties());
    },
    getImageObject() {
        return getTopObjectValue(store._focusObjects, object => {
            if (object.get_ObjectType() != Asc.c_oAscTypeSelectElement.Image) return false;
            const imageObject = object.get_ObjectValue();
            return !!imageObject && !imageObject.get_ShapeProperties() && !imageObject.get_ChartProperties();
        });
    },
    getTableObject() {
        return getTopObjectValue(store._focusObjects, isObjectType(Asc.c_oAscTypeSelectElement.Table));
    },
    getChartObject() {
        return getTopObjectValue(store._focusObjects, object => {
            const value = object.get_ObjectValue();
            return !!value && typeof value.get_ChartProperties === 'function' && !!value.get_ChartProperties();
        });
    },
    getLinkObject() {
        return getTopObjectValue(store._focusObjects, isObjectType(Asc.c_oAscTypeSelectElement.Hyperlink));
    }
});

EditorUIController.initFocusObjects = storeFocusObjects => {
    storeFocusObjects.intf = createFocusObjectsIntf(storeFocusObjects);

    const api = Common.EditorApi.get();
    api.asc_registerCallback('asc_onFocusObject', objects => {
        storeFocusObjects.resetFocusObjects(objects);
    });
};

EditorUIController.initEditorStyles = storeParagraphSettings => {
    const api = Common.EditorApi.get();
    api.asc_setParagraphStylesSizes(330, 38);
    api.asc_registerCallback('asc_onInitEditorStyles', styles => {
        storeParagraphSettings.initEditorStyles(styles);
    });
    api.asc_registerCallback('asc_onParaStyleName', name => {
        storeParagraphSettings.changeParaStyleName(name);
    });
};

EditorUIController.initTableTemplates = storeTableSettings => {
    const api = Common.EditorApi.get();
    api.asc_registerCallback('asc_onInitTableTemplates', () => {
        storeTableSettings.initTableTemplates();
    });
};

EditorUIController.updateChartStyles = (storeChartSettings, storeFocusObjects) => {
    const api = Common.EditorApi.get();
    api.asc_registerCallback('asc_onUpdateChartStyles', () => {
        const chartObject = storeFocusObjects.chartObject;
        const chartProps = chartObject && chartObject.get_ChartProperties();
        if (!chartProps) return;

        // mesmo critério de controller/edit/EditChart.jsx: gráficos combinados não têm estilos
        const type = chartProps.getType();
        if (type == Asc.c_oAscChartTypeSettings.comboBarLine ||
            type == Asc.c_oAscChartTypeSettings.comboBarLineSecondary ||
            type == Asc.c_oAscChartTypeSettings.comboAreaBar ||
            type == Asc.c_oAscChartTypeSettings.comboCustom) {
            storeChartSettings.clearChartStyles();
        } else {
            storeChartSettings.updateChartStyles(api.asc_getChartPreviews(type));
        }
    });
};

EditorUIController.getEditCommentControllers = () => {
    return (
        <Fragment>
            <AddCommentController />
            <EditCommentController />
        </Fragment>
    )
};

EditorUIController.ContextMenu = {
    // Itens do menu de toque quando o usuário pode editar (storeAppOptions.isEdit).
    // Em modo leitura (isViewer) só sobram os itens que não alteram o documento.
    mapMenuItems(contextMenu) {
        if ( !Common.EditorApi ) return [];

        const { t, isViewer, isDisconnected, canViewComments, canCoAuthoring, canComments, canEditComments,
            canReview, canFillForms, isProtected, typeProtection, isForm } = contextMenu.props;
        const _t = t('ContextMenu', { returnObjects: true });

        const api = Common.EditorApi.get();
        const stack = api.getSelectedElements();
        const canCopy = api.can_CopyCut();
        const inToc = api.asc_GetTableOfContentsPr(true);
        const isAllowedEditing = !isProtected || typeProtection === Asc.c_oAscEDocProtect.TrackedChanges;
        const isAllowedCommenting = typeProtection === Asc.c_oAscEDocProtect.Comments;
        const canEditContent = !isViewer && !isDisconnected && isAllowedEditing;

        let isText = false,
            isTable = false,
            isImage = false,
            isChart = false,
            isShape = false,
            isLink = false,
            lockedText = false,
            lockedTable = false,
            lockedImage = false,
            lockedHeader = false;

        stack.forEach(item => {
            const objectType = item.get_ObjectType(),
                objectValue = item.get_ObjectValue();

            if ( objectType == Asc.c_oAscTypeSelectElement.Header ) {
                lockedHeader = objectValue.get_Locked();
            } else
            if ( objectType == Asc.c_oAscTypeSelectElement.Paragraph ) {
                lockedText = objectValue.get_Locked();
                isText = true;
            } else
            if ( objectType == Asc.c_oAscTypeSelectElement.Image ) {
                lockedImage = objectValue.get_Locked();
                if ( objectValue && objectValue.get_ChartProperties() ) {
                    isChart = true;
                } else
                if ( objectValue && objectValue.get_ShapeProperties() ) {
                    isShape = true;
                } else {
                    isImage = true;
                }
            } else
            if ( objectType == Asc.c_oAscTypeSelectElement.Table ) {
                lockedTable = objectValue.get_Locked();
                isTable = true;
            } else
            if ( objectType == Asc.c_oAscTypeSelectElement.Hyperlink ) {
                isLink = true;
            }
        });

        const locked = lockedText || lockedTable || lockedImage || lockedHeader;
        const isObject = isShape || isChart || isImage || isTable;

        let itemsIcon = [],
            itemsText = [];

        // formulários em modo leitura também aceitam cortar e colar, como no menu de leitura
        const canChangeText = !isDisconnected && !locked && isAllowedEditing && canFillForms && (!isViewer || isForm);

        if ( canCopy && canChangeText ) {
            itemsIcon.push({
                event: 'cut',
                icon: IconCut.id
            });
        }

        if ( canCopy ) {
            itemsIcon.push({
                event: 'copy',
                icon: IconCopy.id
            });
        }

        if ( canChangeText ) {
            itemsIcon.push({
                event: 'paste',
                icon: IconPaste.id
            });
        }

        if ( stack.length > 0 && canEditContent ) {
            if ( isTable && api.CheckBeforeMergeCells() && !lockedTable && !lockedHeader ) {
                itemsText.push({
                    caption: _t.menuMerge,
                    event: 'merge'
                });
            }

            if ( isTable && api.CheckBeforeSplitCells() && !lockedTable && !lockedHeader ) {
                itemsText.push({
                    caption: _t.menuSplit,
                    event: 'split'
                });
            }

            if ( !locked ) {
                itemsText.push({
                    caption: _t.menuDelete,
                    event: 'delete'
                });
            }

            if ( isTable && !lockedTable && !lockedText && !lockedHeader ) {
                itemsText.push({
                    caption: _t.menuDeleteTable,
                    event: 'deletetable'
                });
            }

            if ( !locked ) {
                itemsText.push({
                    caption: _t.menuEdit,
                    event: 'edit'
                });
            }

            if ( !!api.can_AddHyperlink() && !lockedHeader ) {
                itemsText.push({
                    caption: _t.menuAddLink,
                    event: 'addlink'
                });
            }

            if ( canReview ) {
                if ( contextMenu.inRevisionChange ) {
                    itemsText.push({
                        caption: _t.menuReviewChange,
                        event: 'reviewchange'
                    });
                } else {
                    itemsText.push({
                        caption: _t.menuReview,
                        event: 'review'
                    });
                }
            }
        }

        if ( !isDisconnected ) {
            if ( canViewComments && contextMenu.isComments ) {
                itemsText.push({
                    caption: _t.menuViewComment,
                    event: 'viewcomment'
                });
            }

            if ( api.can_AddQuotedComment() !== false && canCoAuthoring && canComments && !locked && !(!isText && isObject) &&
                    (!isViewer || canEditComments) && (isAllowedEditing || isAllowedCommenting) ) {
                itemsText.push({
                    caption: _t.menuAddComment,
                    event: 'addcomment'
                });
            }
        }

        if ( isLink ) {
            itemsText.push({
                caption: _t.menuOpenLink,
                event: 'openlink'
            });

            if ( canEditContent ) {
                itemsText.push({
                    caption: _t.menuEditLink,
                    event: 'editlink'
                });
            }
        }

        if ( inToc && canEditContent ) {
            itemsText.push({
                caption: _t.textRefreshEntireTable,
                event: 'refreshEntireTable'
            });
            itemsText.push({
                caption: _t.textRefreshPageNumbersOnly,
                event: 'refreshPageNumbers'
            });
        }

        contextMenu.extraItems = [];
        if ( Device.phone && itemsText.length > 2 ) {
            contextMenu.extraItems = itemsText.splice(2, itemsText.length, {
                caption: _t.menuMore,
                event: 'showActionSheet'
            });
        }

        return itemsIcon.concat(itemsText);
    },

    // Trata as ações de edição. Devolve false para as demais (copiar, ver
    // comentário, abrir link, revisão, sumário), que o controller público trata.
    handleMenuItemClick(contextMenu, action) {
        const api = Common.EditorApi.get();
        const hideWarning = () => LocalStorage.getBool('de-hide-copy-cut-paste-warning');

        switch (action) {
            case 'cut':
                if ( !api.Cut() && !hideWarning() && contextMenu.props.canCopy )
                    contextMenu.showCopyCutPasteModal();
                break;
            case 'paste':
                if ( !api.Paste() && !hideWarning() )
                    contextMenu.showCopyCutPasteModal();
                break;
            case 'addcomment':
                Common.Notifications.trigger('addcomment');
                break;
            case 'merge':
                api.MergeCells();
                break;
            case 'split':
                contextMenu.showSplitModal();
                break;
            case 'delete':
                api.asc_Remove();
                break;
            case 'deletetable':
                api.remTable();
                break;
            case 'edit':
                setTimeout(() => {
                    contextMenu.props.openOptions('edit');
                }, 400);
                break;
            case 'addlink':
                setTimeout(() => {
                    contextMenu.props.openOptions('add-link');
                }, 400);
                break;
            case 'editlink':
                setTimeout(() => {
                    contextMenu.props.openOptions('edit-link');
                }, 400);
                break;
            default:
                return false;
        }

        return true;
    }
};

export default EditorUIController;
